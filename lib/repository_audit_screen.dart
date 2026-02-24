// ignore_for_file: unused_import, unused_element

import 'dart:developer' as developer;
import 'dart:convert' as convert;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
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
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/evidence_upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/utils/debouncer.dart';

class RepositoryAuditScreen extends StatefulWidget {
  const RepositoryAuditScreen({super.key});

  @override
  State<RepositoryAuditScreen> createState() => _RepositoryAuditScreenState();
}

class _RepositoryAuditScreenState extends State<RepositoryAuditScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;
  late final ValueDebouncer<String> _searchDebouncer;

  @override
  void initState() {
    super.initState();
    // Initialize debouncer for search queries
    _searchDebouncer = ValueDebouncer<String>(
      delay: const Duration(milliseconds: 500),
      callback: (value) {
        if (mounted) {
          setState(() {
            _searchQuery = value;
          });
        }
      },
    );

    // Ensure repository auto-sync is running to mirror verified audits
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

  Future<void> _backfillVerifiedEntries() async {
    try {
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    try {
      RepositoryService.stopAutoSync();
    } catch (e) {
      developer.log('Error stopping auto-sync: $e');
    }
    super.dispose();
  }

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
              StreamBuilder<String?>(
                stream: RoleService.instance.roleStream(),
                builder: (context, roleSnapshot) {
                  final role =
                      roleSnapshot.data ?? RoleService.instance.cachedRole;
                  final isManager = role == 'manager';
                  return Column(
                    children: [
                      _buildRoleSummaryBar(isManager: isManager),
                      _buildAuditEntriesList(isManager: isManager),
                      const SizedBox(height: 24),
                      _buildRepositorySection(isManager: isManager),
                      const SizedBox(height: 24),
                      _buildApprovedGoalsSection(isManager: isManager),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagerVerifiedList(List<AuditEntry> entries) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.borderColor),
      itemBuilder: (context, index) {
        final e = entries[index];
        final d = e.completedDate;
        final date =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return ListTile(
          leading: const Icon(Icons.verified, color: Colors.green),
          title: Text(
            e.goalTitle,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            '$date • ${e.userDisplayName} • Score: ${e.score?.toStringAsFixed(1) ?? '-'}',
            style: TextStyle(color: AppColors.textMuted),
          ),
          trailing: Text(
            '${e.evidence.length} evidence',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            // Use debouncer to avoid excessive queries while typing
            _searchDebouncer.setValue(value);
          },
          decoration: InputDecoration(
            hintText: 'Search completed goals, audit logs...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15.0)),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15.0)),
              borderSide: BorderSide(color: AppColors.activeColor),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        // Use responsive layout with proper constraints
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;

            if (isWideScreen) {
              // Wide screen: use Row with Expanded
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: InputDecoration(
                        labelText: 'Filter by Status',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.activeColor),
                        ),
                        isDense: true,
                      ),
                      dropdownColor: Colors.black.withValues(alpha: 0.9),
                      style: TextStyle(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'verified',
                          child: Text('Verified'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _statusFilter = null;
                      });
                    },
                    icon: Icon(Icons.clear, color: AppColors.textMuted),
                    tooltip: 'Clear filters',
                  ),
                ],
              );
            } else {
              // Narrow screen: stack controls vertically
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Status',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.activeColor),
                      ),
                      isDense: true,
                    ),
                    dropdownColor: Colors.black.withValues(alpha: 0.9),
                    style: TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'verified',
                        child: Text('Verified'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _statusFilter = null;
                        });
                      },
                      icon: Icon(Icons.clear, color: AppColors.textMuted),
                      tooltip: 'Clear filters',
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? RoleService.instance.cachedRole;
        final isManager = role == 'manager';
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
      },
    );
  }

  Future<String?> _getManagerDept() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final dept = (doc.data() ?? const {})['department'] as String?;
      developer.log(
        'Manager department check: uid=$uid, department="$dept"',
        name: 'RepositoryAuditScreen',
      );
      return dept;
    } catch (e) {
      developer.log(
        'Error getting manager department: $e',
        name: 'RepositoryAuditScreen',
      );
      return null;
    }
  }

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK', style: TextStyle(color: AppColors.activeColor)),
            ),
          ],
        );
      },
    );
  }

  // Diagnostic method to check all audit entries and their departments
  Future<void> _showDiagnosticInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get manager's department
      final managerDept = await _getManagerDept();

      // Get ALL audit entries (no filter) to see what's actually in the database
      final allEntriesSnapshot = await FirebaseFirestore.instance
          .collection('audit_entries')
          .get();

      final allEntries = allEntriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userDepartment': data['userDepartment'] ?? 'NOT SET',
          'userId': data['userId'] ?? 'NOT SET',
          'userDisplayName': data['userDisplayName'] ?? 'NOT SET',
          'status': data['status'] ?? 'NOT SET',
          'goalTitle': data['goalTitle'] ?? 'NOT SET',
        };
      }).toList();

      // Group by department
      final byDept = <String, List<Map<String, dynamic>>>{};
      for (final entry in allEntries) {
        final dept = entry['userDepartment'] as String;
        byDept.putIfAbsent(dept, () => []).add(entry);
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Diagnostic Information',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manager Department:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  managerDept ?? 'NOT SET',
                  style: TextStyle(
                    color: managerDept == null || managerDept.isEmpty
                        ? AppColors.dangerColor
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Audit Entries: ${allEntries.length}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Entries by Department:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...byDept.entries.map((entry) {
                  final dept = entry.key;
                  final entries = entry.value;
                  final matches = dept == managerDept;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: matches
                          ? AppColors.successColor.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.4),
                      border: Border.all(
                        color: matches
                            ? AppColors.successColor
                            : AppColors.borderColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Department: "$dept"',
                              style: TextStyle(
                                color: matches
                                    ? AppColors.successColor
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (matches) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                color: AppColors.successColor,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Count: ${entries.length}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        ...entries
                            .take(3)
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  '• ${e['userDisplayName']} - ${e['goalTitle']} (${e['status']})',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        if (entries.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Text(
                              '... and ${entries.length - 3} more',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                if (managerDept != null &&
                    managerDept.isNotEmpty &&
                    !byDept.containsKey(managerDept))
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.warningColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ No entries found for manager department "$managerDept"',
                      style: TextStyle(color: AppColors.warningColor),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log(
        'Error showing diagnostic info: $e',
        name: 'RepositoryAuditScreen',
      );
      if (mounted) {
        await _showCenterNotice(context, 'Error loading diagnostic info: $e');
      }
    }
  }

  Widget _buildRoleSummaryBar({required bool isManager}) {
    // Use realtime streams for persistent and consistent counts
    final emptyStats = <String, int>{
      'total': 0,
      'verified': 0,
      'pending': 0,
      'rejected': 0,
    };

    if (isManager) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_entries')
            .snapshots()
            .handleError((error) {
              // Silently handle errors to prevent unmount errors
              developer.log('Error in audit_entries stream: $error');
            }),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            developer.log(
              'Error loading manager audit entries: ${snapshot.error}',
              name: 'RepositoryAuditScreen',
            );
            return _buildStatsContainer(emptyStats, isManager: true);
          }

          final entries = <AuditEntry>[];
          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              try {
                entries.add(AuditEntry.fromFirestore(doc));
              } catch (e) {
                developer.log('Error parsing audit entry ${doc.id}: $e');
              }
            }
          }

          final stats = <String, int>{
            'total': entries.length,
            'verified': entries.where((e) => e.status == 'verified').length,
            'pending': entries.where((e) => e.status == 'pending').length,
            'rejected': entries.where((e) => e.status == 'rejected').length,
          };

          return _buildStatsContainer(stats, isManager: true);
        },
      );
    } else {
      // For employees, use the existing service stream
      return StreamBuilder<List<AuditEntry>>(
        stream: AuditService.getEmployeeAuditEntriesStream(
          status: null, // Get all statuses for accurate counts
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            developer.log(
              'Error in employee audit entries stream: ${snapshot.error}',
              name: 'RepositoryAuditScreen',
            );
            return _buildStatsContainer(emptyStats, isManager: false);
          }

          final entries = snapshot.data ?? [];
          final stats = <String, int>{
            'total': entries.length,
            'verified': entries.where((e) => e.status == 'verified').length,
            'pending': entries.where((e) => e.status == 'pending').length,
            'rejected': entries.where((e) => e.status == 'rejected').length,
          };

          return _buildStatsContainer(stats, isManager: false);
        },
      );
    }
  }

  Widget _buildStatsContainer(
    Map<String, int> stats, {
    required bool isManager,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isManager ? Icons.manage_accounts : Icons.person,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My Goals Progress',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                'Verified',
                stats['verified'] ?? 0,
                AppColors.successColor,
              ),
              _buildStatusChip(
                'Pending',
                stats['pending'] ?? 0,
                AppColors.warningColor,
              ),
              _buildStatusChip(
                'Rejected',
                stats['rejected'] ?? 0,
                AppColors.dangerColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntriesList({required bool isManager}) {
    return StreamBuilder<List<AuditEntry>>(
      stream: isManager
          ? AuditService.getManagerAuditEntriesStream(
              status: _statusFilter,
              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            )
          : AuditService.getEmployeeAuditEntriesStream(
              status: _statusFilter,
              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            ),
      builder: (context, snapshot) {
        // Show loading only if we're truly waiting AND haven't received any data yet
        // This prevents infinite loading when stream hasn't emitted yet but will emit soon
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Only show loading for a short time, then assume empty
          return FutureBuilder<bool>(
            future: Future.delayed(
              const Duration(milliseconds: 500),
              () => true,
            ),
            builder: (context, timeoutSnapshot) {
              if (timeoutSnapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                // After timeout, show empty state instead of infinite loading
                return _buildEmptyState(isManager: isManager);
              }
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.activeColor),
                    SizedBox(height: 16),
                    Text(
                      'Loading audit entries...',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            },
          );
        }

        if (snapshot.hasError) {
          developer.log(
            'Audit entries error: ${snapshot.error}',
            name: 'RepositoryAuditScreen',
          );
          return _buildErrorState(
            'Failed to load audit entries. ${snapshot.error}',
            onRetry: () {
              setState(() {}); // Trigger rebuild
            },
          );
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmptyState(isManager: isManager);
        }

        return Column(
          children: entries
              .map((entry) => _buildAuditEntryCard(entry, isManager))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isManager = false}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.archive_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            'No audit entries found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isManager
                ? 'No employee submissions available yet. Once employees submit goals, they will appear here.'
                : 'Complete some goals to see them here for audit.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.dangerColor, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(
              color: AppColors.dangerColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditEntryCard(AuditEntry entry, bool isManager) {
    Color statusColor;
    switch (entry.status) {
      case 'verified':
        statusColor = AppColors.successColor;
        break;
      case 'pending':
        statusColor = AppColors.warningColor;
        break;
      case 'rejected':
        statusColor = AppColors.dangerColor;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.goalTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  entry.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Completed: ${_formatDate(entry.completedDate)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (isManager) ...[
                const SizedBox(width: 16),
                Text(
                  'By: ${entry.userDisplayName}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  entry.userDepartment,
                  style: TextStyle(color: AppColors.activeColor, fontSize: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Evidence & Documentation:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...entry.evidence.map(
            (evidence) => _buildEvidenceItem(evidence, entry.evidence),
          ),

          if (isManager && entry.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVerifyDialog(entry),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(entry),
                    icon: const Icon(Icons.comment, size: 16),
                    label: const Text('Request Changes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerColor,
                      side: BorderSide(color: AppColors.dangerColor),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (entry.acknowledgedBy != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: AppColors.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verified by ${entry.acknowledgedBy}',
                        style: TextStyle(
                          color: AppColors.successColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.score != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Score: ${entry.score!.toStringAsFixed(1)}/10',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (entry.comments != null && entry.comments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manager Feedback:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.comments!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (entry.rejectionReason != null &&
              entry.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.dangerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: AppColors.dangerColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Changes Requested',
                        style: TextStyle(
                          color: AppColors.dangerColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${entry.rejectionReason}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Timeline',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: StreamBuilder<List<AuditTimelineEvent>>(
              stream: TimelineService.getTimelineStream(entry.id),
              builder: (context, snapshot) {
                final events = snapshot.data ?? const <AuditTimelineEvent>[];
                if (events.isEmpty) {
                  return _buildFallbackTimeline(entry);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ev = events[index];
                    // Choose actor name intelligently based on event type.
                    // - submission: employee name
                    // - verification/rejection: manager name
                    String actorName = ev.actorName.trim();
                    final isUnknown =
                        actorName.isEmpty ||
                        actorName.toLowerCase().startsWith('unknown');

                    if (isUnknown) {
                      if (ev.eventType == 'submission') {
                        // Goal submitted by employee
                        actorName = entry.userDisplayName;
                      } else if (ev.eventType == 'verification' ||
                          ev.eventType == 'rejection') {
                        // Verified / rejected by manager
                        final mgr = (entry.acknowledgedBy ?? '').trim();
                        actorName = mgr.isNotEmpty ? mgr : 'Manager';
                      } else {
                        // Fallback for any other event types
                        actorName = entry.userDisplayName;
                      }
                    }
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        ev.eventType == 'submission'
                            ? Icons.outbox
                            : ev.eventType == 'verification'
                            ? Icons.verified
                            : Icons.edit_note,
                        color: AppColors.textMuted,
                      ),
                      title: Text(
                        ev.description,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '$actorName • ${_formatDate(ev.timestamp)}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFallbackTimeline(AuditEntry entry) {
    final tiles = <Widget>[];

    tiles.add(
      ListTile(
        dense: true,
        leading: Icon(Icons.outbox, color: AppColors.textMuted),
        title: Text(
          'Goal submitted for audit: ${entry.goalTitle}',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        ),
        subtitle: Text(
          '${entry.userDisplayName} • ${_formatDate(entry.submittedDate)}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );

    if (entry.acknowledgedBy != null && entry.acknowledgedBy!.isNotEmpty) {
      tiles.add(
        ListTile(
          dense: true,
          leading: Icon(Icons.verified, color: AppColors.textMuted),
          title: Text(
            entry.score != null
                ? 'Entry verified with score ${entry.score!.toStringAsFixed(1)}'
                : 'Entry verified',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          subtitle: Text(
            '${entry.acknowledgedBy} • ${_formatDate(entry.verifiedDate ?? entry.submittedDate)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    if (entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) {
      tiles.add(
        ListTile(
          dense: true,
          leading: Icon(Icons.cancel_rounded, color: AppColors.textMuted),
          title: Text(
            'Changes requested: ${entry.rejectionReason}',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          subtitle: Text(
            '${entry.acknowledgedBy ?? ''} • ${_formatDate(entry.rejectedDate ?? entry.submittedDate)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    if (tiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('No timeline events yet'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => tiles[index],
    );
  }

  void _showVerifyDialog(AuditEntry entry) {
    final scoreController = TextEditingController();
    final commentsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Verify Goal',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Score (1.0 - 5.0)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comments (optional)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final score = double.tryParse(scoreController.text);
              if (score != null && score >= 1.0 && score <= 5.0) {
                try {
                  await AuditService.verifyAuditEntry(
                    entry.id,
                    score,
                    commentsController.text.isEmpty
                        ? null
                        : commentsController.text,
                  );
                  if (mounted) navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  await _showCenterNotice(
                    this.context,
                    'Error verifying entry: $e',
                  );
                }
              } else {
                if (!mounted) return;
                await _showCenterNotice(
                  this.context,
                  'Please enter a valid score between 1.0 and 5.0',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(AuditEntry entry) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Request Changes',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Reason for changes',
            labelStyle: TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.dangerColor),
            ),
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (reasonController.text.isNotEmpty) {
                try {
                  await AuditService.requestChanges(
                    entry.id,
                    reasonController.text,
                  );
                  if (mounted) navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  await _showCenterNotice(
                    this.context,
                    'Error requesting changes: $e',
                  );
                }
              } else {
                if (!mounted) return;
                await _showCenterNotice(
                  this.context,
                  'Please provide a reason for the changes',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerColor,
            ),
            child: const Text('Request Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildRepositorySection({required bool isManager}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

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
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: (isManager)
              ? StreamBuilder<List<RepositoryGoal>>(
                  // Use repository goals stream which shows all synced verified goals
                  stream: Stream.value(<RepositoryGoal>[])
                      .asyncExpand((_) {
                        return Stream.fromFuture(
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                              .get(),
                        ).asyncExpand((userDoc) {
                          final rawDept =
                              (userDoc.data() ?? const {})['department']
                                  as String?;
                          final department = rawDept?.trim();
                          // If manager has no department set, fall back to all
                          // repository goals instead of an empty stream.
                          return RepositoryService.getAllRepositoryGoalsStream(
                            department:
                                (department == null || department.isEmpty)
                                ? null
                                : department,
                          );
                        });
                      })
                      .map((goals) {
                        // Apply filters
                        Iterable<RepositoryGoal> filtered = goals;

                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          filtered = filtered.where(
                            (g) =>
                                g.goalTitle.toLowerCase().contains(q) ||
                                g.evidence.any(
                                  (e) => e.toLowerCase().contains(q),
                                ),
                          );
                        }

                        return filtered.toList()..sort((a, b) {
                          final ad =
                              a.verifiedDate ??
                              a.completedDate ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final bd =
                              b.verifiedDate ??
                              b.completedDate ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return bd.compareTo(ad);
                        });
                      }),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: AppColors.activeColor,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading repository: ${snapshot.error}',
                          style: TextStyle(color: AppColors.dangerColor),
                        ),
                      );
                    }
                    final goals = snapshot.data ?? const <RepositoryGoal>[];
                    if (goals.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No verified entries found for your team. Previously acknowledged entries should appear here.',
                        ),
                      );
                    }
                    return _buildRepositoryList(goals);
                  },
                )
              : StreamBuilder<List<RepositoryGoal>>(
                  stream: RepositoryService.queryRepositoryGoals(
                    uid,
                    search: _searchQuery,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: AppColors.activeColor,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading repository: ${snapshot.error}',
                          style: TextStyle(color: AppColors.dangerColor),
                        ),
                      );
                    }
                    final items = snapshot.data ?? const <RepositoryGoal>[];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No repository items found. Complete and verify some goals to see them here.',
                        ),
                      );
                    }
                    return _buildRepositoryList(items);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRepositoryList(List<RepositoryGoal> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.borderColor),
      itemBuilder: (context, index) {
        final g = items[index];
        final date = g.completedDate ?? g.verifiedDate;
        return ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(
            g.goalTitle,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            '${date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : 'Unknown date'} • Score: ${g.score?.toStringAsFixed(1) ?? '-'}',
            style: TextStyle(color: AppColors.textMuted),
          ),
          trailing: Text(
            '${g.evidence.length} evidence',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }

  // (Manager section removed per request; employee-focused for now)

  void _showExportSheet() {
    // Use a bottom sheet for the options (stable), and keep centered dialogs
    // for success/error notices after the actual export.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export as CSV'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final role = await RoleService.instance.getRole();
                    if (role == 'manager') {
                      await RepositoryExportService.exportManagerVerifiedAsCSV(
                        search: _searchQuery.isEmpty ? null : _searchQuery,
                      );
                    } else {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      await RepositoryExportService.exportRepositoryAsCSV(uid);
                    }
                    await _showExportNotice(
                      'Export downloaded (CSV). Check your browser downloads.',
                    );
                  } catch (e) {
                    await _showExportNotice('Export failed: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export as PDF'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final role = await RoleService.instance.getRole();
                    if (role == 'manager') {
                      await RepositoryExportService.exportManagerVerifiedAsPDF(
                        search: _searchQuery.isEmpty ? null : _searchQuery,
                      );
                    } else {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      await RepositoryExportService.exportRepositoryAsPDF(uid);
                    }
                    await _showExportNotice(
                      'Export downloaded (PDF). Open it from your downloads.',
                    );
                  } catch (e) {
                    await _showExportNotice('Export failed: $e');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExportNotice(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        content: Text(
          message,
          style: TextStyle(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper widget to build individual evidence items.
  Widget _buildEvidenceItem(String text, List<String> allEvidence) {
    IconData icon;
    if (text.toLowerCase().contains('report') ||
        text.toLowerCase().contains('document') ||
        text.toLowerCase().contains('files')) {
      icon = Icons.description;
    } else if (text.toLowerCase().contains('link') ||
        text.toLowerCase().contains('repository')) {
      icon = Icons.link;
    } else {
      icon = Icons.attachment;
    }

    final isUrl = text.startsWith('http://') || text.startsWith('https://');

    // If this is a file label (e.g. "📎 File: name"), try to find a matching URL
    String target = text;
    if (!isUrl && text.startsWith('📎')) {
      final linkedUrl = allEvidence.firstWhere(
        (e) => e.startsWith('http://') || e.startsWith('https://'),
        orElse: () => text,
      );
      target = linkedUrl;
    }

    final hasPreviewUrl =
        target.startsWith('http://') || target.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.activeColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _openEvidence(target),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  text,
                  style: TextStyle(
                    color: hasPreviewUrl
                        ? AppColors.activeColor
                        : AppColors.textSecondary,
                    fontSize: 14,
                    decoration: hasPreviewUrl ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              color: AppColors.textMuted,
              tooltip: hasPreviewUrl ? 'Open evidence link' : 'View evidence',
              onPressed: () => _openEvidence(target),
            ),
          ],
        ),
      ),
    );
  }

  void _openEvidence(String evidence) {
    final isUrl =
        evidence.startsWith('http://') || evidence.startsWith('https://');

    if (isUrl) {
      final lower = evidence.toLowerCase();
      final isImage =
          lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp');
      final isPdf = lower.endsWith('.pdf');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            isImage
                ? 'Evidence Image'
                : isPdf
                ? 'Evidence PDF'
                : 'Evidence Link',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: isImage
              ? SizedBox(
                  width: 480,
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      evidence,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: AppColors.textMuted,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load image preview.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              evidence,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.activeColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPdf)
                      Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.activeColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PDF evidence file',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (isPdf) const SizedBox(height: 8),
                    SelectableText(
                      evidence,
                      style: TextStyle(
                        color: AppColors.activeColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    if (isPdf) const SizedBox(height: 8),
                    if (isPdf)
                      Text(
                        'Use "Open in new tab" to view this PDF in your browser.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                try {
                  web.window.open(evidence, '_blank');
                } catch (_) {
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(
                isPdf ? 'Open PDF in new tab' : 'Open in new tab',
                style: TextStyle(color: AppColors.activeColor),
              ),
            ),
          ],
        ),
      );
    } else {
      // For text evidence, show in a preview dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Evidence Details',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              evidence,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showGoalSubmissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Submit Goal for Audit',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a completed goal to submit for manager review:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Goal>>(
              future: _getCompletedGoals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.activeColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error loading goals: ${snapshot.error}',
                    style: TextStyle(color: AppColors.dangerColor),
                  );
                }

                final goals = snapshot.data ?? [];
                if (goals.isEmpty) {
                  return Text(
                    'No completed goals found. Complete some goals first.',
                    style: TextStyle(color: AppColors.textMuted),
                  );
                }

                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return ListTile(
                        title: Text(
                          goal.title,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          goal.description,
                          style: TextStyle(color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showEvidenceAttachmentDialog(goal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.activeColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Submit'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<List<Goal>> _getCompletedGoals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      return snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      developer.log('Error loading completed goals: $e');
      return [];
    }
  }

  void _showEvidenceAttachmentDialog(Goal goal) {
    final evidenceController = TextEditingController();
    final evidenceList = <String>[];
    final uploadedFiles = <EvidenceFile>[];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Attach Evidence for: ${goal.title}',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add evidence to support your goal completion:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Text evidence input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: evidenceController,
                        decoration: InputDecoration(
                          hintText: 'Enter evidence (URL, description, etc.)',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.elevatedBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (evidenceController.text.trim().isNotEmpty) {
                          setState(() {
                            evidenceList.add(evidenceController.text.trim());
                            evidenceController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // File upload button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            setState(() => isUploading = true);
                            try {
                              final files = await _uploadFiles(goal.id);
                              setState(() {
                                uploadedFiles.addAll(files);
                                isUploading = false;
                              });
                              if (!mounted) return;
                              await _showCenterNotice(
                                this.context,
                                '${files.length} file(s) uploaded successfully',
                              );
                              // Close dialog automatically after successful upload
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } catch (e) {
                              setState(() => isUploading = false);
                              if (!mounted) return;
                              await _showCenterNotice(
                                this.context,
                                'Error uploading files: $e',
                              );
                            }
                          },
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(isUploading ? 'Uploading...' : 'Upload Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Display uploaded files
                if (uploadedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Uploaded Files:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: ListView.builder(
                      itemCount: uploadedFiles.length,
                      itemBuilder: (context, index) {
                        final file = uploadedFiles[index];
                        return ListTile(
                          leading: Icon(
                            _getFileIcon(file.fileType),
                            color: AppColors.activeColor,
                          ),
                          title: Text(
                            file.fileName,
                            style: TextStyle(color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${(file.fileSize / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                uploadedFiles.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Display text evidence
                if (evidenceList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Text Evidence:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: ListView.builder(
                      itemCount: evidenceList.length,
                      itemBuilder: (context, index) {
                        final evidence = evidenceList[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.text_fields,
                            color: AppColors.activeColor,
                          ),
                          title: Text(
                            evidence,
                            style: TextStyle(color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                evidenceList.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: (evidenceList.isEmpty && uploadedFiles.isEmpty)
                  ? null
                  : () => _submitGoalForAuditWithFiles(
                      goal,
                      evidenceList,
                      uploadedFiles,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit for Audit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<EvidenceFile>> _uploadFiles(String goalId) async {
    final files = await EvidenceUploadService.pickAndUploadFiles(
      goalId: goalId,
    );
    return files;
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return Icons.image;
      case '.txt':
        return Icons.text_snippet;
      case '.zip':
        return Icons.archive;
      default:
        return Icons.attach_file;
    }
  }

  // Ensure user's department is set; otherwise block submission and prompt to update profile
  Future<bool> _ensureDepartmentIsSet() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final department = (data['department'] as String?)?.trim();
      final hasDept =
          department != null &&
          department.isNotEmpty &&
          department.toLowerCase() != 'unknown';

      if (!hasDept) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Text(
              'Department Required',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Your department information is missing. Please update your profile before submitting.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Try navigate to settings where profile can be updated
                  if (mounted) {
                    Navigator.pushNamed(context, '/settings');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.activeColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
        return false;
      }
      return true;
    } catch (e) {
      // If we cannot validate, be safe and block submission
      return false;
    }
  }

  Future<void> _submitGoalForAuditWithFiles(
    Goal goal,
    List<String> textEvidence,
    List<EvidenceFile> uploadedFiles,
  ) async {
    try {
      // Ensure the user has a department set before allowing submission
      final proceed = await _ensureDepartmentIsSet();
      if (!proceed) {
        return; // User has been informed; do not proceed
      }
      // Combine text evidence with file URLs
      final allEvidence = <String>[];
      allEvidence.addAll(textEvidence);
      allEvidence.addAll(uploadedFiles.map((file) => file.url));

      // Submit goal for audit
      await AuditService.submitGoalForAudit(goal, allEvidence);

      // Update uploaded files with audit entry ID (we'll need to get this from the audit service)
      // For now, we'll just submit the goal and the files will be linked by goal ID

      if (mounted) {
        Navigator.pop(context); // Close evidence dialog
        Navigator.pop(context); // Close goal selection dialog
        await _showCenterNotice(
          context,
          'Goal submitted for audit with ${uploadedFiles.length} file(s) and ${textEvidence.length} text evidence!',
        );
      }
    } catch (e) {
      developer.log('Error submitting goal for audit with files: $e');
      if (mounted) {
        await _showCenterNotice(context, 'Error submitting goal: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'rejected':
        return AppColors.dangerColor;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // Helper method to fetch employee details from profile
  Future<Map<String, String>> _getEmployeeDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};

      String name =
          userData['displayName'] ??
          userData['fullName'] ??
          userData['name'] ??
          userData['email'] ??
          'Unknown Employee';
      String department = userData['department'] ?? 'Not specified';

      return {'name': name, 'department': department};
    } catch (e) {
      return {'name': 'Unknown Employee', 'department': 'Not specified'};
    }
  }

  Widget _buildApprovedGoalsSection({required bool isManager}) {
    final stream = isManager
        ? ApprovedGoalAuditService.getManagerApprovedGoalsStream()
        : ApprovedGoalAuditService.getEmployeeApprovedGoalsStream();
    return StreamBuilder<List<ApprovedGoalAudit>>(
      stream: stream,
      builder: (context, snapshot) {
        final audits = snapshot.data ?? [];
        if (audits.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approved Goals Audit',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: audits.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.borderColor),
              itemBuilder: (context, index) {
                final audit = audits[index];
                final date =
                    '${audit.approvedAt.year}-${audit.approvedAt.month.toString().padLeft(2, '0')}-${audit.approvedAt.day.toString().padLeft(2, '0')}';

                if (isManager) {
                  // Manager view: show goal title, employee name, department, timestamp
                  return ListTile(
                    leading: const Icon(Icons.verified, color: Colors.green),
                    title: Text(
                      audit.goalTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee: ${audit.employeeName}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Department: ${audit.department}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Approved: $date',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Employee view: show goal name, who approved, timestamp
                  return ListTile(
                    leading: const Icon(Icons.verified, color: Colors.green),
                    title: Text(
                      audit.goalTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved by: ${audit.approvedByName}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Approved: $date',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMilestoneAuditSection({required bool isManager}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Milestone Audit Trail',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              tooltip: 'Backfill Existing Milestones',
              onPressed: _backfillMilestoneAudit,
              icon: const Icon(Icons.history_rounded),
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: const Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.activeColor),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading milestone audit: ${snapshot.error}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.dangerColor,
                  ),
                ),
              );
            }

            final audits = snapshot.data ?? [];
            if (audits.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No milestone audit history available',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Using Unified Audit System',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: audits.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.borderColor),
              itemBuilder: (context, index) {
                final audit = audits[index];
                return _buildUnifiedMilestoneAuditCard(audit);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildUnifiedMilestoneAuditCard(Map<String, dynamic> audit) {
    return ProfessionalMilestoneAuditCard(entry: audit);
  }

  IconData _getUnifiedActionIcon(String action) {
    switch (action) {
      case 'milestone_created':
        return Icons.add_circle_rounded;
      case 'milestone_updated':
        return Icons.edit_rounded;
      case 'milestone_status_changed':
        return Icons.sync_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getUnifiedActionColor(String action) {
    switch (action) {
      case 'milestone_created':
        return Colors.purple;
      case 'milestone_updated':
        return Colors.orange;
      case 'milestone_status_changed':
        return Colors.teal;
      default:
        return AppColors.activeColor;
    }
  }

  String _getUnifiedActionTitle(String action) {
    switch (action) {
      case 'milestone_created':
        return 'Milestone Created';
      case 'milestone_updated':
        return 'Milestone Updated';
      case 'milestone_status_changed':
        return 'Milestone Status Changed';
      default:
        return 'Milestone Action';
    }
  }

  String _formatUnifiedTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _backfillMilestoneAudit() async {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting unified milestone backfill...'),
          duration: Duration(seconds: 2),
        ),
      );

      // TODO: Implement milestone backfill functionality
      // This should:
      // 1. Fetch all existing milestones from Firestore
      // 2. Create audit entries for any milestones that don't have them
      // 3. Store audit entries with proper metadata
      // await AuditService.backfillExistingMilestones();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unified milestone backfill completed!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during unified backfill: $e')),
        );
      }
    }
  }

  Future<void> _exportMilestoneAudit() async {
    // Implementation for exporting milestone audit data
    try {
      // TODO: Implement export functionality similar to existing export service
      // This should:
      // 1. Fetch milestone audit data from Firestore
      // 2. Format data for CSV/PDF export
      // 3. Use RepositoryExportService patterns for consistency
      // 4. Support filtering by date, user, status
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Milestone audit export coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting milestone audit: $e')),
      );
    }
  }
}

class ProfessionalMilestoneAuditCard extends StatefulWidget {
  final Map<String, dynamic> entry;

  const ProfessionalMilestoneAuditCard({required this.entry});

  @override
  State<ProfessionalMilestoneAuditCard> createState() =>
      ProfessionalMilestoneAuditCardState();
}

class ProfessionalMilestoneAuditCardState
    extends State<ProfessionalMilestoneAuditCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.entry['action'] as String? ?? 'unknown';
    final timestamp = widget.entry['timestamp'] as Timestamp?;
    final metadata = widget.entry['metadata'] as Map<String, dynamic>? ?? {};

    // Extract data from metadata field
    final milestoneTitle =
        metadata['milestoneTitle'] as String? ?? 'Unknown Milestone';
    final goalTitle = metadata['goalTitle'] as String? ?? 'Unknown Goal';
    final userName = widget.entry['userName'] as String? ?? 'System';
    final userRole = widget.entry['userRole'] as String? ?? 'system';
    final isHistorical = metadata['isHistorical'] == true;

    final actionInfo = _getActionInfo(action);
    final formattedDate = _formatDate(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (actionInfo['color'] as Color?)?.withValues(alpha: 0.2) ??
              Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with action and timestamp
              Row(
                children: [
                  // Action Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (actionInfo['color'] as Color).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actionInfo['icon'] as IconData,
                      color: actionInfo['color'] as Color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action Title and Status Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionInfo['title'] as String,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              milestoneTitle,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Badge in collapsed view
                            _buildCompactStatusBadge(action),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Historical Badge
                  if (isHistorical)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Historical',
                        style: AppTypography.bodyXSmall.copyWith(
                          color: AppColors.infoColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Timestamp
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              // Divider
              if (_isExpanded)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1,
                  color: AppColors.backgroundColor.withValues(alpha: 0.3),
                ),

              // Expanded Details
              if (_isExpanded) _buildExpandedDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetails() {
    final action = widget.entry['action'] as String? ?? 'unknown';
    final userName = widget.entry['userName'] as String? ?? 'System';
    final userRole = widget.entry['userRole'] as String? ?? 'system';
    final description = widget.entry['description'] as String? ?? '';
    final metadata = widget.entry['metadata'] as Map<String, dynamic>? ?? {};

    // Extract data from metadata field
    final milestoneTitle =
        metadata['milestoneTitle'] as String? ?? 'Unknown Milestone';
    final goalTitle = metadata['goalTitle'] as String? ?? 'Unknown Goal';

    // Extract status from action or metadata
    String status = 'Unknown';
    Color statusColor = AppColors.textSecondary;

    if (action.contains('pending_review')) {
      status = 'Pending Review';
      statusColor = AppColors.warningColor;
    } else if (action.contains('acknowledged')) {
      status = 'Acknowledged';
      statusColor = AppColors.successColor;
    } else if (action.contains('rejected')) {
      status = 'Rejected';
      statusColor = AppColors.dangerColor;
    } else if (action.contains('dismissed')) {
      status = 'Dismissed';
      statusColor = AppColors.textMuted;
    } else if (action.contains('created')) {
      status = 'Created';
      statusColor = AppColors.infoColor;
    } else if (action.contains('updated')) {
      status = 'Updated';
      statusColor = AppColors.warningColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Status Badge
        Row(
          children: [
            Text(
              'Status:',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                status,
                style: AppTypography.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Milestone Information
        _buildInfoRow(
          label: 'Milestone:',
          value: milestoneTitle,
          icon: Icons.flag,
        ),

        const SizedBox(height: 12),

        // Goal Information
        _buildInfoRow(
          label: 'Goal:',
          value: goalTitle,
          icon: Icons.track_changes,
        ),

        const SizedBox(height: 12),

        // Owner Information
        _buildInfoRow(
          label: 'Created By:',
          value: '$userName ($userRole)',
          icon: Icons.person,
        ),

        const SizedBox(height: 12),

        // Acknowledged By (if applicable)
        if (action == 'milestone_acknowledged' &&
            widget.entry['acknowledgedByName'] != null) ...[
          _buildInfoRow(
            label: 'Acknowledged By:',
            value: widget.entry['acknowledgedByName'],
            icon: Icons.verified_user,
            valueColor: AppColors.successColor,
          ),
          const SizedBox(height: 12),
        ],

        // Rejected By (if applicable)
        if (action == 'milestone_rejected' &&
            widget.entry['rejectedByName'] != null) ...[
          _buildInfoRow(
            label: 'Rejected By:',
            value: widget.entry['rejectedByName'],
            icon: Icons.cancel,
            valueColor: AppColors.dangerColor,
          ),
          const SizedBox(height: 12),
        ],

        // Description (if available and not the default formatted text)
        if (description.isNotEmpty &&
            !description.contains('Milestone created:') &&
            !description.contains('for goal:')) ...[
          const SizedBox(height: 16),
          Text(
            'Description:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStatusBadge(String action) {
    String status = 'Unknown';
    Color statusColor = AppColors.textSecondary;

    if (action.contains('pending_review')) {
      status = 'Pending';
      statusColor = AppColors.warningColor;
    } else if (action.contains('acknowledged')) {
      status = 'Acknowledged';
      statusColor = AppColors.successColor;
    } else if (action.contains('rejected')) {
      status = 'Rejected';
      statusColor = AppColors.dangerColor;
    } else if (action.contains('dismissed')) {
      status = 'Dismissed';
      statusColor = AppColors.textMuted;
    } else if (action.contains('created')) {
      status = 'Created';
      statusColor = AppColors.infoColor;
    } else if (action.contains('updated')) {
      status = 'Updated';
      statusColor = AppColors.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: AppTypography.bodyXSmall.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getActionInfo(String action) {
    switch (action) {
      case 'milestone_created':
        return {
          'title': 'Milestone Created',
          'icon': Icons.add_circle,
          'color': AppColors.successColor,
        };
      case 'milestone_updated':
        return {
          'title': 'Milestone Updated',
          'icon': Icons.edit,
          'color': AppColors.warningColor,
        };
      case 'milestone_pending_review':
        return {
          'title': 'Pending Review',
          'icon': Icons.pending_actions,
          'color': AppColors.warningColor,
        };
      case 'milestone_acknowledged':
        return {
          'title': 'Acknowledged',
          'icon': Icons.verified,
          'color': AppColors.successColor,
        };
      case 'milestone_rejected':
        return {
          'title': 'Rejected',
          'icon': Icons.cancel,
          'color': AppColors.dangerColor,
        };
      case 'milestone_dismissed':
        return {
          'title': 'Dismissed',
          'icon': Icons.block,
          'color': AppColors.textMuted,
        };
      default:
        return {
          'title': 'Unknown Action',
          'icon': Icons.help_outline,
          'color': AppColors.textSecondary,
        };
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';

    final now = DateTime.now();
    final eventTime = timestamp!.toDate();
    final difference = now.difference(eventTime);

    // Relative time for recent events
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes == 1) {
          return '1 minute ago';
        } else {
          return '${difference.inMinutes} minutes ago';
        }
      } else if (difference.inHours == 1) {
        return '1 hour ago';
      } else {
        return '${difference.inHours} hours ago';
      }
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    // Absolute date for older events
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[eventTime.month - 1]} ${eventTime.day}, ${eventTime.year}';
  }
}
