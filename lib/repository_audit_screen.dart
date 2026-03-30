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
import 'package:pdh/services/robust_stream_manager.dart';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html'
    as html; // Keep using dart:html for now until migration to package:web is complete

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
    developer.log(
      'RepositoryAuditScreen: initState started',
      name: 'RepositoryAuditScreen',
    );

    // Initialize debouncer for search queries
    _searchDebouncer = ValueDebouncer<String>(
      delay: const Duration(milliseconds: 500),
      callback: (value) {
        if (mounted) {
          setState(() {
            // Search filter updated
          });
        }
      },
    );

    // Add timeout to prevent infinite loading
    Timer(const Duration(seconds: 30), () {
      if (mounted && _isInitializing) {
        developer.log(
          'RepositoryAuditScreen: Initialization timeout - forcing UI update',
          name: 'RepositoryAuditScreen',
        );

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
      await _initializeUnifiedStream();

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

  // Initialize unified stream with proper error handling
  Future<void> _initializeUnifiedStream() async {
    developer.log(
      'RepositoryAuditScreen: Initializing unified stream',
      name: 'RepositoryAuditScreen',
    );

    if (_unifiedStreamSubscription != null) {
      developer.log(
        'RepositoryAuditScreen: Stream already exists, cancelling previous',
        name: 'RepositoryAuditScreen',
      );
      await _unifiedStreamSubscription!.cancel();
      _unifiedStreamSubscription = null;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Use the robust stream manager to get a shared stream
      final streamManager = RobustStreamManager();
      final stream = streamManager.getAuditEntriesStream(
        userId: user.uid,
        isManager: _isManager,
        limit: 500,
      );

      developer.log(
        'RepositoryAuditScreen: Created stream, setting up listener',
        name: 'RepositoryAuditScreen',
      );

      _unifiedStreamSubscription = stream.listen(
        (snapshot) {
          if (mounted) {
            developer.log(
              'RepositoryAuditScreen: Stream received ${snapshot.docs.length} documents',
              name: 'RepositoryAuditScreen',
            );

            // Debug: Print first document data
            if (snapshot.docs.isNotEmpty) {
              final firstDoc = snapshot.docs.first;
              developer.log(
                'RepositoryAuditScreen: First document data: ${firstDoc.data()}',
                name: 'RepositoryAuditScreen',
              );
            }

            _processStreamData(snapshot);
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log(
              'RepositoryAuditScreen: Stream error: $error',
              name: 'RepositoryAuditScreen',
              error: error,
            );

            setState(() {
              _isInitializing = false;
              _lastError = 'Stream error: $error';
              _hasLoadedOnce = true;
            });
          }
        },
        onDone: () {
          developer.log(
            'RepositoryAuditScreen: Stream completed',
            name: 'RepositoryAuditScreen',
          );
        },
      );

      developer.log(
        'RepositoryAuditScreen: Stream listener setup complete',
        name: 'RepositoryAuditScreen',
      );
    } catch (e) {
      developer.log(
        'RepositoryAuditScreen: Error creating stream: $e',
        name: 'RepositoryAuditScreen',
      );
      throw Exception('Failed to create unified stream: $e');
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
    developer.log(
      'RepositoryAuditScreen: Disposing',
      name: 'RepositoryAuditScreen',
    );

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

  // Get cached audit entries for UI
  List<AuditEntry> getCachedAuditEntries() {
    return _allAuditEntries;
  }

  @override
  Widget build(BuildContext context) {
    developer.log(
      'RepositoryAuditScreen: Building UI - isInitializing: $_isInitializing, hasLoadedOnce: $_hasLoadedOnce, entries: ${_allAuditEntries.length}',
      name: 'RepositoryAuditScreen',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Repository & Audit'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_lastError != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _retryInitialization,
              tooltip: 'Retry',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshMilestoneAudits,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    developer.log(
      'RepositoryAuditScreen: _buildBody called - isInitializing: $_isInitializing, hasLoadedOnce: $_hasLoadedOnce, entries: ${_allAuditEntries.length}, error: $_lastError',
      name: 'RepositoryAuditScreen',
    );

    // Show error state
    if (_lastError != null && _allAuditEntries.isEmpty) {
      return _buildErrorState();
    }

    // Show loading state during initialization
    if (_isInitializing) {
      return _buildLoadingState();
    }

    // Fallback debug state if somehow we reach here with no data
    if (_allAuditEntries.isEmpty && _milestoneAudits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No data available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryInitialization,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Add mock data for testing
                setState(() {
                  _allAuditEntries = [
                    AuditEntry(
                      id: 'test1',
                      userId: 'test',
                      goalId: 'goal1',
                      goalTitle: 'Test Goal 1',
                      completedDate: DateTime.now(),
                      submittedDate: DateTime.now(),
                      status: 'created',
                      evidence: [],
                      userDisplayName: 'Test User',
                      userDepartment: 'Test Dept',
                    ),
                    AuditEntry(
                      id: 'test2',
                      userId: 'test',
                      goalId: 'goal2',
                      goalTitle: 'Test Goal 2',
                      completedDate: DateTime.now(),
                      submittedDate: DateTime.now(),
                      status: 'pending',
                      evidence: [],
                      userDisplayName: 'Test User 2',
                      userDepartment: 'Test Dept 2',
                    ),
                  ];
                  _isInitializing = false;
                  _hasLoadedOnce = true;
                });
              },
              child: const Text('Add Mock Data'),
            ),
          ],
        ),
      );
    }

    // Show main content
    return RefreshIndicator(
      onRefresh: _retryInitialization,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildRoleSummaryBar(isManager: _isManager),
            const SizedBox(height: 16),
            _buildSearchAndFilters(),
            const SizedBox(height: 16),
            _buildStatsContainer({
              'total': _allAuditEntries.length,
              'created': _allAuditEntries
                  .where((e) => e.status == 'created')
                  .length,
              'pending': _allAuditEntries
                  .where((e) => e.status == 'pending')
                  .length,
              'approved': _allAuditEntries
                  .where((e) => e.status == 'verified')
                  .length,
              'rejected': _allAuditEntries
                  .where((e) => e.status == 'rejected')
                  .length,
              'verified': _allAuditEntries
                  .where((e) => e.status == 'verified')
                  .length,
            }, isManager: _isManager),
            const SizedBox(height: 24),
            _buildAuditEntriesList(),
            const SizedBox(height: 24),
            _buildMilestoneAuditSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing Repository & Audit...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Initialization Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lastError ?? 'Unknown error',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _retryInitialization,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSummaryBar({required bool isManager}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          Icon(
            isManager ? Icons.admin_panel_settings : Icons.person,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isManager ? 'Manager View' : 'Employee View',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_lastError != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Error',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
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

  Widget _buildStatsContainer(
    Map<String, int> stats, {
    required bool isManager,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
              _buildStatItem('Created', stats['created'] ?? 0, Colors.grey),
              _buildStatItem('Pending', stats['pending'] ?? 0, Colors.orange),
              _buildStatItem('Verified', stats['verified'] ?? 0, Colors.green),
              _buildStatItem('Rejected', stats['rejected'] ?? 0, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAuditEntriesList() {
    final entries = _getFilteredEntries();

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'No audit entries found',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your filters or check back later',
                style: TextStyle(color: Color(0xFF757575), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Audit Entries (${entries.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...entries.map((entry) => _buildAuditEntryCard(entry)),
        ],
      ),
    );
  }

  List<AuditEntry> _getFilteredEntries() {
    var entries = getCachedAuditEntries();

    // Apply status filter
    if (_statusFilter != null) {
      entries = entries.where((e) => e.status == _statusFilter).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      entries = entries
          .where(
            (e) =>
                e.goalTitle.toLowerCase().contains(searchLower) ||
                (e.comments?.toLowerCase().contains(searchLower) ?? false),
          )
          .toList();
    }

    return entries;
  }

  Widget _buildAuditEntryCard(AuditEntry entry) {
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
              Expanded(
                child: Text(
                  entry.goalTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(entry.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'User: ${entry.userDisplayName}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Department: ${entry.userDepartment}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (entry.comments?.isNotEmpty == true)
            Text(
              entry.comments!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                'Submitted: ${entry.submittedDate.toString().split(' ')[0]}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
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
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMilestoneAuditSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Milestone Audit Trail',
                  style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingMilestones)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _refreshMilestoneAudits,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          if (_milestoneAudits.isEmpty && !_isLoadingMilestones)
            Container(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.timeline, color: Colors.grey, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No milestone audits found',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._milestoneAudits.map((audit) => _buildMilestoneAuditCard(audit)),
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
}
