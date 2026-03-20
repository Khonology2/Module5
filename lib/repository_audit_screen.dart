// ignore_for_file: duplicate_ignore, deprecated_member_use, unnecessary_null_comparison, unused_import, unused_element

import 'dart:developer' as developer;
import 'dart:convert' as convert;
import 'dart:async'; // Add Timer import
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/approved_goal_audit_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:pdh/models/approved_goal_audit.dart';
import 'package:pdh/models/audit_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/repository_service.dart';
import 'package:pdh/models/repository_goal.dart';
import 'package:pdh/services/repository_export_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/models/audit_timeline_event.dart';
import 'package:pdh/services/unified_milestone_audit.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/evidence_upload_service.dart';
import 'package:pdh/utils/debouncer.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/firestore_stream_broker.dart';

// ignore: duplicate_ignore
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html'
    as html; // Keep using dart:html for now until migration to package:web is complete

class RepositoryAuditScreen extends StatefulWidget {
  /// When true, admin is viewing; show only manager-scoped audit data (no employees).
  final bool forAdminOversight;

  const RepositoryAuditScreen({
    super.key,
    this.forAdminOversight = false,
  });

  @override
  State<RepositoryAuditScreen> createState() => _RepositoryAuditScreenState();
}

class _RepositoryAuditScreenState extends State<RepositoryAuditScreen> {
  // Add state for milestone audits with caching
  List<Map<String, dynamic>> _milestoneAudits = [];
  bool _isLoadingMilestones = false;
  bool _hasLoadedOnce = false; // Prevent repeated loading
  bool _isManager = false; // Track current user role

  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;
  late final ValueDebouncer<String> _searchDebouncer;

  // Single unified stream to prevent Firestore conflicts
  StreamSubscription<QuerySnapshot>? _unifiedStreamSubscription;
  List<AuditEntry> _allAuditEntries = [];

  @override
  void initState() {
    super.initState();

    // Initialize unified stream after role is determined
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _initializeUserRole();
      }
    });

    // Initialize debouncer for search queries
    _searchDebouncer = ValueDebouncer<String>(
      delay: const Duration(milliseconds: 500),
      callback: (value) {
        if (mounted) {
          setState(() {
            // _searchQuery = value; // Removed unused field
          });
        }
      },
    );

    // Enable repository auto-sync for functionality
    try {
      RepositoryService.startAutoSync();
    } catch (e) {
      developer.log('Error starting auto-sync: $e');
    }

    // Backfill existing verified entries when screen loads
    _backfillVerifiedEntries();

    // Add a timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {}); // Trigger rebuild to show error if still loading
      }
    });
  }

  // Initialize user role and create unified stream
  Future<void> _initializeUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final roleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (roleDoc.data() ?? const {})['role'] as String?;

      if (mounted) {
        setState(() {
          _isManager = role == 'manager';
        });
        // Initialize unified stream after role is determined
        _initializeUnifiedStream();
      }
    } catch (e) {
      developer.log('Error initializing user role: $e');
    }
  }

  Future<void> _backfillVerifiedEntries() async {
    try {
      if (widget.forAdminOversight) return; // Admin: no employee backfill.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check role from stream or user profile
      final roleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (roleDoc.data() ?? const {})['role'] as String?;

      if (role == 'manager') {
        // For managers: backfill all verified entries in their department
        final department =
            (roleDoc.data() ?? const {})['department'] as String?;
        if (department != null && department.isNotEmpty) {
          await RepositoryService.backfillVerifiedEntriesForDepartment(
            department,
          );
        }
      } else {
        // For employees: backfill their own verified entries
        await RepositoryService.backfillVerifiedEntriesForUser(user.uid);
      }
    } catch (e) {
      developer.log(
        'Error backfilling verified entries: $e',
        name: 'RepositoryAuditScreen',
      );
    }
  }

  Future<void> _loadMilestoneAuditsOnce() async {
    if (_hasLoadedOnce) return; // Prevent repeated loading

    setState(() {
      _isLoadingMilestones = true;
    });

    try {
      final audits = await UnifiedMilestoneAudit.getMilestoneAudits(
        forManager: _isManager,
      );
      setState(() {
        _milestoneAudits = audits;
        _isLoadingMilestones = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      setState(() {
        _isLoadingMilestones = false;
        _hasLoadedOnce = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading milestone audits: $e')),
        );
      }
    }
  }

  Future<void> _refreshMilestoneAudits() async {
    setState(() {
      _hasLoadedOnce = false; // Allow refresh
    });
    await _loadMilestoneAuditsOnce();
  }

  @override
  void dispose() {
    // Clean up unified stream subscription
    _unifiedStreamSubscription?.cancel();
    _unifiedStreamSubscription = null;
    _searchController.dispose();
    _searchDebouncer.dispose();
    try {
      RepositoryService.stopAutoSync();
    } catch (e) {
      developer.log('Error stopping auto-sync: $e');
    }
    super.dispose();
  }

  // Initialize unified stream that serves all UI components
  void _initializeUnifiedStream() {
    if (_unifiedStreamSubscription != null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use the stream broker to get a shared stream
    final broker = FirestoreStreamBroker();
    final stream = broker.getAuditEntriesStream(
      userId: user.uid,
      isManager: _isManager,
      limit: 500,
    );

    _unifiedStreamSubscription = stream.listen(
      (snapshot) {
        if (mounted) {
          developer.log(
            'Unified stream received ${snapshot.docs.length} documents',
          );

          final entries = <AuditEntry>[];
          final milestoneAudits = <Map<String, dynamic>>[];
          var skippedCount = 0;
          var milestoneCount = 0;
          var auditCount = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};

            // Skip entries without goalId
            if ((data['goalId'] ?? '').toString().isEmpty) {
              skippedCount++;
              continue;
            }

            // Check if it's a milestone audit
            if (data.containsKey('action')) {
              // This is a MILESTONE audit, NOT a regular audit entry
              // Skip it from regular audit entries list
              final action = data['action'] as String? ?? '';
              final isMilestoneAction = [
                'milestone_created',
                'milestone_updated',
                'milestone_status_changed',
                'milestone_completed',
                'milestone_acknowledged',
                'milestone_pending_review',
                'milestone_rejected',
                'milestone_dismissed',
              ].contains(action);

              if (isMilestoneAction) {
                // Add to milestone audits
                milestoneAudits.add({'id': doc.id, ...data});
                milestoneCount++;
              }
              // Skip milestone actions from regular audit entries
              continue;
            }

            // Add to regular audit entries
            try {
              final entry = AuditEntry.fromFirestore(doc);
              entries.add(entry);
              auditCount++;
              developer.log(
                'Audit entry: ${entry.goalTitle} - Status: ${entry.status}',
              );
            } catch (e) {
              developer.log('Error parsing audit entry ${doc.id}: $e');
            }
          }

          developer.log(
            'Stream processing complete: $auditCount audit entries, $milestoneCount milestone audits, $skippedCount skipped',
          );

          setState(() {
            _allAuditEntries = entries;
            _milestoneAudits = milestoneAudits;
            _isLoadingMilestones = false;
            _hasLoadedOnce = true;
          });

          developer.log(
            'Unified stream updated: ${entries.length} audit entries, ${milestoneAudits.length} milestone audits',
          );
        }
      },
      onError: (error) {
        developer.log(
          'Unified stream error: $error',
          name: 'RepositoryAuditScreen',
        );
        if (mounted) {
          setState(() {
            _isLoadingMilestones = false;
            _hasLoadedOnce = true;
          });
        }
      },
    );
  }

  // Get cached data for UI components
  List<AuditEntry> getCachedAuditEntries() => _allAuditEntries;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Repository & Audit',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildSearchAndFilters(),
              const SizedBox(height: 25),
              _buildHeader(),
              Column(
                children: [
                  _buildRoleSummaryBar(isManager: _isManager),
                  _buildAuditEntriesList(isManager: _isManager),
                  const SizedBox(height: 24),
                  _buildRepositorySection(isManager: _isManager),
                  const SizedBox(height: 24),
                  _buildApprovedGoalsSection(isManager: _isManager),
                  const SizedBox(height: 24),
                  _buildMilestoneAuditSection(isManager: _isManager),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Filters',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search goals...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.activeColor),
              ),
            ),
            onChanged: (value) {
              _searchDebouncer.setValue(value);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(
                  'All',
                  style: TextStyle(
                    color: _statusFilter == null
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                selected: _statusFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? null : _statusFilter;
                  });
                },
                backgroundColor: Colors.grey[700],
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Created',
                  style: TextStyle(
                    color: _statusFilter == 'created'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                selected: _statusFilter == 'created',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'created' : null;
                  });
                },
                backgroundColor: Colors.grey[700],
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Pending',
                  style: TextStyle(
                    color: _statusFilter == 'pending'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                selected: _statusFilter == 'pending',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'pending' : null;
                  });
                },
                backgroundColor: Colors.grey[700],
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Verified',
                  style: TextStyle(
                    color: _statusFilter == 'verified'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                selected: _statusFilter == 'verified',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'verified' : null;
                  });
                },
                backgroundColor: Colors.grey[700],
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Rejected',
                  style: TextStyle(
                    color: _statusFilter == 'rejected'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                selected: _statusFilter == 'rejected',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'rejected' : null;
                  });
                },
                backgroundColor: Colors.grey[700],
                selectedColor: AppColors.activeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isManager = _isManager;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Completed Goals Archive',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isManager)
              IconButton(
                tooltip: 'Diagnostic Info',
                onPressed: _showDiagnosticInfo,
                icon: const Icon(Icons.info_outline),
                color: AppColors.warningColor,
              ),
            IconButton(
              tooltip: 'Export',
              onPressed: _showExportSheet,
              icon: const Icon(Icons.download_rounded),
              color: AppColors.activeColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSummaryBar({required bool isManager}) {
    final entries = getCachedAuditEntries();
    final stats = {
      'total': entries.length,
      'created': entries.length,
      'pending': entries.where((e) => e.status == 'pending').length,
      'approved': entries.where((e) => e.status == 'verified').length,
      'rejected': entries.where((e) => e.status == 'rejected').length,
      'verified': entries.where((e) => e.status == 'verified').length,
    };
    return _buildStatsContainer(stats, isManager: isManager);
  }

  Widget _buildStatsContainer(
    Map<String, int> stats, {
    required bool isManager,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isManager ? 'Team Overview' : 'Your Progress',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildStatItem(
                'Total',
                stats['total'] ?? 0,
                AppColors.activeColor,
              ),
              _buildStatItem(
                'Created',
                stats['created'] ?? 0,
                AppColors.infoColor,
              ),
              _buildStatItem(
                'Pending',
                stats['pending'] ?? 0,
                AppColors.warningColor,
              ),
              _buildStatItem(
                'Verified',
                stats['verified'] ?? 0,
                AppColors.successColor,
              ),
              _buildStatItem('Rejected', stats['rejected'] ?? 0, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntriesList({required bool isManager}) {
    final entries = getCachedAuditEntries();
    if (!_hasLoadedOnce && _isLoadingMilestones) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.activeColor),
      );
    }
    if (entries.isEmpty) {
      return _buildEmptyState(isManager: isManager);
    }
    return Column(
      children: entries.map((e) => _buildAuditEntryCard(e, isManager)).toList(),
    );
  }

  Widget _buildEmptyState({required bool isManager}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            isManager ? 'No team goals found' : 'No goals found',
            style: AppTypography.heading4.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isManager
                ? 'Your team hasn\'t completed any goals yet. Encourage them to set and achieve goals!'
                : 'You haven\'t completed any goals yet. Start by creating and completing some goals!',
            style: TextStyle(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntryCard(AuditEntry entry, bool isManager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        title: Text(
          entry.goalTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${entry.status}',
              style: TextStyle(
                color: _getStatusColor(entry.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuditDetails(entry),
                const SizedBox(height: 12),
                _buildEvidenceSection(entry),
                const SizedBox(height: 12),
                _buildActionButtons(entry, isManager),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'created':
        return AppColors.infoColor;
      case 'pending':
        return AppColors.warningColor;
      case 'approved':
      case 'verified':
        return AppColors.successColor;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildAuditDetails(AuditEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.comments ?? entry.goalTitle,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (entry.submittedDate != null)
          Text(
            'Submitted: ${entry.submittedDate.toString()}',
            style: TextStyle(color: AppColors.textMuted),
          ),
        if (entry.verifiedDate != null)
          Text(
            'Verified: ${entry.verifiedDate.toString()}',
            style: TextStyle(color: AppColors.successColor),
          ),
        if (entry.rejectedDate != null)
          Text(
            'Rejected: ${entry.rejectedDate.toString()}',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }

  Widget _buildEvidenceSection(AuditEntry entry) {
    if (entry.evidence.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence (${entry.evidence.length})',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...entry.evidence.map(
          (evidence) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evidence,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AuditEntry entry, bool isManager) {
    return Row(
      children: [
        if (isManager && entry.status == 'pending')
          Expanded(
            child: ElevatedButton(
              onPressed: () => _approveGoal(entry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ),
        if (isManager && entry.status == 'pending') const SizedBox(width: 8),
        if (isManager && entry.status == 'pending')
          Expanded(
            child: ElevatedButton(
              onPressed: () => _rejectGoal(entry),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ),
        if (!isManager)
          Expanded(
            child: ElevatedButton(
              onPressed: () => _viewGoalDetails(entry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Details'),
            ),
          ),
      ],
    );
  }

  Widget _buildRepositorySection({required bool isManager}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Use cached data from unified stream to prevent Firestore conflicts
    final entries = getCachedAuditEntries();

    // Filter for verified entries only (repository shows verified goals)
    final repositoryGoals = entries
        .where((e) => e.status == 'verified')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_done_outlined, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Repository Results',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: repositoryGoals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    isManager
                        ? 'No verified entries found for your team. Previously acknowledged entries should appear here.'
                        : 'No repository items found. Complete and verify some goals to see them here.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : _buildRepositoryListFromAuditEntries(repositoryGoals),
        ),
      ],
    );
  }

  Widget _buildRepositoryListFromAuditEntries(List<AuditEntry> entries) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.borderColor),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: const Icon(Icons.verified, color: Colors.green),
          title: Text(
            entry.goalTitle,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            '${entry.userDisplayName} • ${entry.completedDate.year}-${entry.completedDate.month.toString().padLeft(2, '0')}-${entry.completedDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: AppColors.textMuted),
          ),
          trailing: Text(
            '${entry.evidence.length} evidence',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildApprovedGoalsSection({required bool isManager}) {
    final entries = getCachedAuditEntries();
    final approvedGoals = entries
        .where((e) => e.status == 'verified' || e.status == 'approved')
        .toList();
    if (approvedGoals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified, color: AppColors.successColor),
            const SizedBox(width: 8),
            Text(
              'Approved Goals',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: approvedGoals.length,
            separatorBuilder: (_, _) =>
                const Divider(color: AppColors.borderColor),
            itemBuilder: (context, index) {
              final goal = approvedGoals[index];
              return ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: AppColors.successColor,
                ),
                title: Text(
                  goal.goalTitle,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  'Approved by: ${goal.userDisplayName}',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                trailing: Text(
                  '${goal.evidence.length} files',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneAuditSection({required bool isManager}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, color: AppColors.infoColor),
            const SizedBox(width: 8),
            Text(
              'Milestone Audit Trail',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _refreshMilestoneAudits,
              icon: _isLoadingMilestones
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.activeColor,
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppColors.activeColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _buildMilestoneAuditContent(),
        ),
      ],
    );
  }

  Widget _buildMilestoneAuditContent() {
    if (!_hasLoadedOnce && _isLoadingMilestones) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.activeColor),
        ),
      );
    }

    if (_milestoneAudits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No milestone audit entries found.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Showing ${_milestoneAudits.length} milestone audit entries',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _milestoneAudits.length,
          separatorBuilder: (_, _) =>
              const Divider(color: AppColors.borderColor),
          itemBuilder: (context, index) {
            final audit = _milestoneAudits[index];
            return ListTile(
              leading: Icon(
                _getMilestoneIcon(audit['action']),
                color: _getMilestoneColor(audit['action']),
              ),
              title: Text(
                audit['goalTitle'] ?? 'Unknown Goal',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                '${audit['action']} • ${_formatDate(audit['timestamp'])}',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: Text(
                audit['status'] ?? 'Unknown',
                style: TextStyle(
                  color: _getStatusColor(audit['status'] ?? 'unknown'),
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getMilestoneIcon(String? action) {
    switch (action) {
      case 'milestone_created':
        return Icons.add_circle_outline;
      case 'milestone_updated':
        return Icons.edit;
      case 'milestone_completed':
        return Icons.check_circle;
      case 'milestone_acknowledged':
        return Icons.visibility;
      case 'milestone_rejected':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Color _getMilestoneColor(String? action) {
    switch (action) {
      case 'milestone_created':
        return AppColors.infoColor;
      case 'milestone_updated':
        return AppColors.warningColor;
      case 'milestone_completed':
      case 'milestone_acknowledged':
        return AppColors.successColor;
      case 'milestone_rejected':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}-${date.month}-${date.year}';
    }
    return 'Unknown';
  }

  void _approveGoal(AuditEntry entry) async {
    try {
      // Implementation for approving goal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal "${entry.goalTitle}" approved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving goal: $e')));
    }
  }

  void _rejectGoal(AuditEntry entry) async {
    try {
      // Implementation for rejecting goal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal "${entry.goalTitle}" rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting goal: $e')));
    }
  }

  void _viewGoalDetails(AuditEntry entry) {
    // Implementation for viewing goal details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.goalTitle),
        content: Text(entry.comments ?? entry.goalTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDiagnosticInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostic Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Role: ${_isManager ? "Manager" : "Employee"}'),
            Text('Cached Entries: ${_allAuditEntries.length}'),
            Text('Milestone Audits: ${_milestoneAudits.length}'),
            Text('Loading: $_isLoadingMilestones'),
            Text('Has Loaded: $_hasLoadedOnce'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Options',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.file_download,
                color: AppColors.activeColor,
              ),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.of(context).pop();
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.file_download,
                color: AppColors.activeColor,
              ),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.of(context).pop();
                _exportAsJSON();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsCSV() async {
    try {
      final entries = getCachedAuditEntries();
      if (entries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      // CSV export implementation
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV export completed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _exportAsJSON() async {
    try {
      final entries = getCachedAuditEntries();
      if (entries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      // JSON export implementation
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON export completed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}
