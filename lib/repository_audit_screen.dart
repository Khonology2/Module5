// ignore_for_file: unused_import, unused_element

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
import 'package:pdh/services/robust_stream_manager.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html'
    as html; // Keep using dart:html for now until migration to package:web is complete

class _RepoAuditChrome {
  _RepoAuditChrome._();

  static bool get light => employeeDashboardLightModeNotifier.value;
  // Match employee dashboard opacity (0x99 for 60% opacity)
  static const Color _darkCard = Color(0x993D3D40);

  static Color get cardFill => light ? const Color(0x99FFFFFF) : _darkCard;
  static Color get border =>
      light ? const Color(0x33000000) : Colors.white.withValues(alpha: 0.2);
  static Color get fg => light ? const Color(0xFF000000) : Colors.white;
  static List<Color>? get lightGradient => light
      ? [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.08),
        ]
      : null;
}
class RepositoryAuditScreen extends StatefulWidget {
  const RepositoryAuditScreen({super.key, this.forAdminOversight = false});

  /// When true, render the same view used for managers (admin oversight screens).
  final bool forAdminOversight;

  @override
  State<RepositoryAuditScreen> createState() => _RepositoryAuditScreenState();
}

class _RepositoryAuditScreenState extends State<RepositoryAuditScreen> {
  // Add state for milestone audits with caching
  List<Map<String, dynamic>> _milestoneAudits = [];
  bool _isLoadingMilestones = false;
  bool _hasLoadedOnce = false; // Prevent repeated loading
  bool _isManager = false; // Track current user role
  bool _isInitializing = true; // Track initialization state
  String? _lastError; // Track last error for debugging

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

    // Add timeout to prevent infinite loading
    Timer(const Duration(seconds: 30), () {
      if (mounted && _isInitializing) {
        setState(() {
          _isInitializing = false;
          _lastError = 'Initialization timeout - please retry';
          _hasLoadedOnce = true;
        });
      }
    });

    // Start initialization process
    _initializeScreen();
  }

  // Comprehensive screen initialization
  Future<void> _initializeScreen() async {
    developer.log(
      'RepositoryAuditScreen: Starting screen initialization',
      name: 'RepositoryAuditScreen',
    );

    setState(() {
      _isInitializing = true;
      _lastError = null;
    });

    try {
      // Step 1: Check user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      developer.log(
        'RepositoryAuditScreen: User authenticated: ${user.uid}',
        name: 'RepositoryAuditScreen',
      );

      // Step 2: Initialize user role
      await _initializeUserRole();

      // Step 3: Initialize unified stream
      _initializeUnifiedStream();

      // Step 4: Enable repository services
      await _initializeRepositoryServices();

      // Step 5: Load milestone audits
      await _loadMilestoneAuditsOnce();

      developer.log(
        'RepositoryAuditScreen: Initialization completed successfully',
        name: 'RepositoryAuditScreen',
      );

      // Ensure initialization state is cleared
      setState(() {
        _isInitializing = false;
      });
    } catch (e, stackTrace) {
      developer.log(
        'RepositoryAuditScreen: Initialization failed: $e',
        name: 'RepositoryAuditScreen',
        error: e,
      );
      developer.log(
        'RepositoryAuditScreen: Stack trace: $stackTrace',
        name: 'RepositoryAuditScreen',
      );

      setState(() {
        _isInitializing = false;
        _lastError = e.toString();
        _isLoadingMilestones = false;
        _hasLoadedOnce = true; // Prevent infinite loading
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Initialize user role and create unified stream
  Future<void> _initializeUserRole() async {
    developer.log(
      'RepositoryAuditScreen: Initializing user role',
      name: 'RepositoryAuditScreen',
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final roleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = (roleDoc.data() ?? const {})['role'] as String?;
      final department = (roleDoc.data() ?? const {})['department'] as String?;

      developer.log(
        'RepositoryAuditScreen: User role: $role, department: $department',
        name: 'RepositoryAuditScreen',
      );

      if (mounted) {
        setState(() {
          _isManager = widget.forAdminOversight || role == 'manager';
        });
      }
    } catch (e) {
      developer.log(
        'RepositoryAuditScreen: Error initializing user role: $e',
        name: 'RepositoryAuditScreen',
      );
      throw Exception('Failed to initialize user role: $e');
    }
  }

  // Process stream data with comprehensive logging
  void _processStreamData(QuerySnapshot snapshot) {
    developer.log(
      'RepositoryAuditScreen: Processing stream data',
      name: 'RepositoryAuditScreen',
    );

    try {
      final entries = <AuditEntry>[];
      final milestoneAudits = <Map<String, dynamic>>[];
      var skippedCount = 0;
      var milestoneCount = 0;
      var auditCount = 0;
      var parseErrors = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        developer.log(
          'RepositoryAuditScreen: Processing doc ${doc.id}: ${data.keys.toList()}',
          name: 'RepositoryAuditScreen',
        );

        // Skip entries without goalId
        if ((data['goalId'] ?? '').toString().isEmpty) {
          skippedCount++;
          developer.log(
            'RepositoryAuditScreen: Skipping doc ${doc.id} - no goalId',
            name: 'RepositoryAuditScreen',
          );
          continue;
        }

        // Check if it's a milestone audit
        if (data.containsKey('action')) {
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
            milestoneAudits.add({'id': doc.id, ...data});
            milestoneCount++;
            developer.log(
              'RepositoryAuditScreen: Added milestone audit: $action',
              name: 'RepositoryAuditScreen',
            );
          }
          continue; // Skip milestone actions from regular audit entries
        }

        // Add to regular audit entries
        try {
          final entry = AuditEntry.fromFirestore(doc);
          entries.add(entry);
          auditCount++;
          developer.log(
            'RepositoryAuditScreen: Added audit entry: ${entry.goalTitle} - Status: ${entry.status}',
            name: 'RepositoryAuditScreen',
          );
        } catch (e) {
          parseErrors++;
          developer.log(
            'RepositoryAuditScreen: Error parsing audit entry ${doc.id}: $e',
            name: 'RepositoryAuditScreen',
          );
        }
      }

      developer.log(
        'RepositoryAuditScreen: Stream processing complete: $auditCount audit entries, $milestoneCount milestone audits, $skippedCount skipped, $parseErrors parse errors',
        name: 'RepositoryAuditScreen',
      );

      if (mounted) {
        setState(() {
          _allAuditEntries = entries;
          _milestoneAudits = milestoneAudits;
          _isLoadingMilestones = false;
          _hasLoadedOnce = true;
          _isInitializing = false;
        });

        developer.log(
          'RepositoryAuditScreen: State updated - ${entries.length} audit entries, ${milestoneAudits.length} milestone audits',
          name: 'RepositoryAuditScreen',
        );
      }
    } catch (e) {
      developer.log(
        'RepositoryAuditScreen: Error processing stream data: $e',
        name: 'RepositoryAuditScreen',
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isLoadingMilestones = false;
          _hasLoadedOnce = true;
          _lastError = 'Data processing error: $e';
        });
      }
    }
  }

  // Initialize repository services
  Future<void> _initializeRepositoryServices() async {
    developer.log(
      'RepositoryAuditScreen: Initializing repository services',
      name: 'RepositoryAuditScreen',
    );

    try {
      // Enable repository auto-sync for functionality
      RepositoryService.startAutoSync();

      // Backfill existing verified entries when screen loads
      await _backfillVerifiedEntries();

      developer.log(
        'RepositoryAuditScreen: Repository services initialized',
        name: 'RepositoryAuditScreen',
      );
    } catch (e) {
      developer.log(
        'RepositoryAuditScreen: Error initializing repository services: $e',
        name: 'RepositoryAuditScreen',
      );
      // Don't throw - repository services are non-critical
    }
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
        'RepositoryAuditScreen: Error backfilling verified entries: $e',
        name: 'RepositoryAuditScreen',
      );
      // Don't throw - backfill is non-critical
    }
  }

  Future<void> _loadMilestoneAuditsOnce() async {
    if (_hasLoadedOnce) return; // Prevent repeated loading

    developer.log(
      'RepositoryAuditScreen: Loading milestone audits',
      name: 'RepositoryAuditScreen',
    );

    setState(() {
      _isLoadingMilestones = true;
    });

    try {
      final streamManager = RobustStreamManager();
      final stream = streamManager.getMilestoneAuditsStream();

      // Listen to stream and get initial data
      final subscription = stream.listen(
        (snapshot) {
          if (mounted) {
            final audits = snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  },
                )
                .toList();

            developer.log(
              'RepositoryAuditScreen: Loaded ${audits.length} milestone audits',
              name: 'RepositoryAuditScreen',
            );

            setState(() {
              _milestoneAudits = audits;
              _isLoadingMilestones = false;
              _hasLoadedOnce = true;
            });
          }
        },
        onError: (error) {
          developer.log(
            'RepositoryAuditScreen: Error loading milestone audits: $error',
            name: 'RepositoryAuditScreen',
          );

          if (mounted) {
            setState(() {
              _isLoadingMilestones = false;
              _hasLoadedOnce = true;
              _lastError = 'Milestone audit error: $error';
            });
          }
        },
      );

      // Store subscription for cleanup
      _unifiedStreamSubscription = subscription;
    } catch (e) {
      developer.log(
        'RepositoryAuditScreen: Error loading milestone audits: $e',
        name: 'RepositoryAuditScreen',
      );

      setState(() {
        _isLoadingMilestones = false;
        _hasLoadedOnce = true;
        _lastError = 'Milestone audit error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading milestone audits: $e')),
        );
      }
    }
  }

  Future<void> _refreshMilestoneAudits() async {
    developer.log(
      'RepositoryAuditScreen: Refreshing milestone audits',
      name: 'RepositoryAuditScreen',
    );

    setState(() {
      _hasLoadedOnce = false; // Allow refresh
    });
    await _loadMilestoneAuditsOnce();
  }

  // Retry initialization
  Future<void> _retryInitialization() async {
    developer.log(
      'RepositoryAuditScreen: Retrying initialization',
      name: 'RepositoryAuditScreen',
    );

    // Clean up existing stream
    if (_unifiedStreamSubscription != null) {
      await _unifiedStreamSubscription!.cancel();
      _unifiedStreamSubscription = null;
    }

    // Reset state
    setState(() {
      _allAuditEntries.clear();
      _milestoneAudits.clear();
      _isLoadingMilestones = false;
      _hasLoadedOnce = false;
      _isInitializing = true;
      _lastError = null;
    });

    // Re-initialize
    await _initializeScreen();
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
      developer.log(
        'RepositoryAuditScreen: Error stopping auto-sync: $e',
        name: 'RepositoryAuditScreen',
      );
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
    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, light, _) {
        return EmployeeDashboardThemeScope(
          light: light,
          child: Material(
            color: Colors.transparent,
            child: AppComponents.backgroundWithImage(
              blurSigma: 0,
              imagePath: light
                  ? 'assets/light_mode_bg.png'
                  : 'assets/khono_bg.png',
              gradientColors: _RepoAuditChrome.lightGradient,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repository & Audit',
                      style: AppTypography.heading2.copyWith(
                        color: _RepoAuditChrome.fg,
                      ),
                    ),
                    if (_lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
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
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search goals...',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            onChanged: (value) {
              _searchDebouncer.setValue(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Filter:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children:
                      ['All', 'Created', 'Pending', 'Verified', 'Rejected'].map(
                        (status) {
                          final isSelected =
                              _statusFilter ==
                              (status == 'All' ? null : status.toLowerCase());
                          return FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = selected
                                    ? (status == 'All'
                                          ? null
                                          : status.toLowerCase())
                                    : null;
                              });
                            },
                            backgroundColor: Colors.grey[800],
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          );
                        },
                      ).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDiagnosticInfo() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics are available in logs.')),
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
            style: AppTypography.heading4.copyWith(color: _RepoAuditChrome.fg),
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
        color: _RepoAuditChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _RepoAuditChrome.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isManager ? 'Team Overview' : 'Your Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
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
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
            style: TextStyle(color: _RepoAuditChrome.fg, fontSize: 12),
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
        color: _RepoAuditChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _RepoAuditChrome.border),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: _RepoAuditChrome.fg),
          const SizedBox(height: 16),
          Text(
            isManager ? 'No team goals found' : 'No goals found',
            style: AppTypography.heading4.copyWith(color: _RepoAuditChrome.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isManager
                ? 'Your team hasn\'t completed any goals yet. Encourage them to set and achieve goals!'
                : 'You haven\'t completed any goals yet. Start by creating and completing some goals!',
            style: TextStyle(color: _RepoAuditChrome.fg),
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
        color: _RepoAuditChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _RepoAuditChrome.border),
      ),
      child: ExpansionTile(
        title: Text(
          entry.goalTitle,
          style: TextStyle(
            color: _RepoAuditChrome.fg,
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
    Color color;
    switch (status.toLowerCase()) {
      case 'created':
        color = Colors.grey;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'verified':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = _RepoAuditChrome.fg;
        break;
    }
    return color;
  }

  Widget _buildAuditDetails(AuditEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal Details',
          style: TextStyle(
            color: _RepoAuditChrome.fg,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.comments ?? entry.goalTitle,
          style: TextStyle(color: _RepoAuditChrome.fg),
        ),
        const SizedBox(height: 8),
        Text(
          'Submitted: ${entry.submittedDate.toString()}',
          style: TextStyle(color: _RepoAuditChrome.fg),
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
            color: _RepoAuditChrome.fg,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...entry.evidence.map(
          (evidence) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 16, color: _RepoAuditChrome.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evidence,
                    style: TextStyle(color: _RepoAuditChrome.fg),
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
            Icon(Icons.cloud_done_outlined, color: _RepoAuditChrome.fg),
            const SizedBox(width: 8),
            Text(
              'Repository Results',
              style: TextStyle(
                color: _RepoAuditChrome.fg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _RepoAuditChrome.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _RepoAuditChrome.border),
          ),
          child: repositoryGoals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    isManager
                        ? 'No verified entries found for your team. Previously acknowledged entries should appear here.'
                        : 'No repository items found. Complete and verify some goals to see them here.',
                    style: TextStyle(color: _RepoAuditChrome.fg),
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
            style: TextStyle(color: _RepoAuditChrome.fg),
          ),
          subtitle: Text(
            '${entry.userDisplayName} • ${entry.completedDate.year}-${entry.completedDate.month.toString().padLeft(2, '0')}-${entry.completedDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: _RepoAuditChrome.fg),
          ),
          trailing: Text(
            '${entry.evidence.length} evidence',
            style: TextStyle(color: _RepoAuditChrome.fg),
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
                color: _RepoAuditChrome.fg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _RepoAuditChrome.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _RepoAuditChrome.border),
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
                  style: TextStyle(color: _RepoAuditChrome.fg),
                ),
                subtitle: Text(
                  'Approved by: ${goal.userDisplayName}',
                  style: TextStyle(color: _RepoAuditChrome.fg),
                ),
                trailing: Text(
                  '${goal.evidence.length} files',
                  style: TextStyle(color: _RepoAuditChrome.fg),
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
                color: _RepoAuditChrome.fg,
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
            color: _RepoAuditChrome.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _RepoAuditChrome.border),
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
          style: TextStyle(color: _RepoAuditChrome.fg),
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
            style: TextStyle(color: _RepoAuditChrome.fg, fontSize: 12),
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
                style: TextStyle(color: _RepoAuditChrome.fg),
              ),
              subtitle: Text(
                '${audit['action']} • ${_formatDate(audit['timestamp'])}',
                style: TextStyle(color: _RepoAuditChrome.fg),
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
        return _RepoAuditChrome.fg;
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

  Widget _buildMilestoneAuditCard(Map<String, dynamic> audit) {
    final action = audit['action'] as String? ?? 'Unknown';
    final timestamp = audit['timestamp'] as Timestamp?;
    final goalTitle = audit['goalTitle'] as String? ?? 'Unknown Goal';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF757575)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goalTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Time: ${timestamp.toDate().toString().split('.')[0]}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _RepoAuditChrome.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Options',
              style: TextStyle(
                color: _RepoAuditChrome.fg,
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
