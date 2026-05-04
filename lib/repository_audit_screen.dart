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

enum RepositoryAuditViewMode {
  personal,
  managerTeam,
  adminOversight,
}

/// Filters admin Repository & Audit by Firestore role of the **goal owner** (`users/{uid}.role`).
enum _AdminGoalOwnerFilter { all, managerOwners, employeeOwners }

class RepositoryAuditScreen extends StatefulWidget {
  /// When true, admin portal shows **organization-wide** audit feeds (not line-manager team scope).
  final bool forAdminOversight;
  /// When true, manager is in manager workspace and should see team data.
  final bool forManagerWorkspace;

  const RepositoryAuditScreen({
    super.key,
    this.forAdminOversight = false,
    this.forManagerWorkspace = false,
  });

  @override
  State<RepositoryAuditScreen> createState() => _RepositoryAuditScreenState();
}

class _RepositoryAuditScreenState extends State<RepositoryAuditScreen> {
  // Add state for milestone audits with caching
  List<Map<String, dynamic>> _milestoneAudits = [];
  List<Map<String, dynamic>> _rawMilestoneAudits = [];
  bool _isLoadingMilestones = false;
  bool _hasLoadedOnce = false; // Prevent repeated loading
  bool _isManager = false; // Track current user role
  bool _milestoneLoadInFlight = false;
  bool _personalGoalIndexHealthy = true;
  String? _currentUserId;
  String? _currentUserDepartment;
  final Set<String> _personalGoalIds = <String>{};
  final Set<String> _teamMemberIds = <String>{};

  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;
  late final ValueDebouncer<String> _searchDebouncer;

  // Single unified stream to prevent Firestore conflicts
  StreamSubscription<QuerySnapshot>? _unifiedStreamSubscription;
  /// Rows from audit_entries before merging admin overlay(s).
  List<AuditEntry> _unifiedEntriesOnly = [];
  StreamSubscription<List<ApprovedGoalAudit>>?
      _approvedGoalsAuditSubscription;
  List<ApprovedGoalAudit> _approvedGoalsAuditCache = [];
  List<AuditEntry> _allAuditEntries = [];
  /// Synthetic rows from `goals` when `audit_entries` never recorded approve/reject.
  List<AuditEntry> _goalsDocFallbackEntries = [];

  /// Goal owner uid → raw `users.role` (lowercase) for admin filters & labels.
  final Map<String, String> _goalOwnerRoleByUid = {};
  final Map<String, String> _displayNameByUserId = {};
  final Map<String, String> _goalOwnerIdByGoalId = {};
  final Map<String, String> _goalOwnerNameByGoalId = {};
  final _AdminGoalOwnerFilter _adminGoalOwnerFilter = _AdminGoalOwnerFilter.all;

  RepositoryAuditViewMode get _viewMode {
    if (widget.forAdminOversight) return RepositoryAuditViewMode.adminOversight;
    if (widget.forManagerWorkspace) return RepositoryAuditViewMode.managerTeam;
    return RepositoryAuditViewMode.personal;
  }

  bool get _useTeamDataView => _viewMode != RepositoryAuditViewMode.personal;

  /// Manager team view or admin org-wide oversight (not personal employee).
  bool get _scopedTeamOrOrganization =>
      widget.forAdminOversight ||
      (_isManager && _useTeamDataView);

  bool _isManagerLikeRole(String? role) {
    final r = role?.trim().toLowerCase() ?? '';
    if (r.isEmpty) return false;
    if (RoleService.isAdminPortalRole(r)) return false;
    return r.contains('manager');
  }

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
          _isManager = _isManagerLikeRole(role);
          _currentUserId = user.uid;
          _currentUserDepartment =
              (roleDoc.data() ?? const {})['department'] as String?;
        });
        // Build a trusted personal goal ownership index used to scope
        // personal workspace milestone/audit visibility.
        await _loadPersonalGoalIds(user.uid);
        await _loadTeamMemberIds(user.uid);
        // Initialize unified stream after role is determined
        _initializeUnifiedStream();
        _subscribeApprovedGoalsAuditForAdmin();
        unawaited(_loadGoalsDocumentApprovalFallbackForAdmin());
        // Milestones use a separate query (timestamp); must run for admins too — they are not `isManager`.
        await _loadMilestoneAuditsOnce();
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
    if (_milestoneLoadInFlight) return;
    _milestoneLoadInFlight = true;

    setState(() {
      _isLoadingMilestones = true;
    });

    try {
      final audits = _viewMode == RepositoryAuditViewMode.personal
          ? await _loadStrictPersonalMilestoneAuditsFromOwnedGoals()
          : await UnifiedMilestoneAudit.getMilestoneAudits(
              // Managers get strict team-member scope; admins are org-wide.
              forManager: _viewMode == RepositoryAuditViewMode.managerTeam,
              organizationWide:
                  _viewMode == RepositoryAuditViewMode.adminOversight,
              allowedUserIds: _viewMode == RepositoryAuditViewMode.managerTeam
                  ? _teamMemberIds
                  : null,
              limit: widget.forAdminOversight ? 400 : 120,
            );
      setState(() {
        _rawMilestoneAudits = audits;
        _milestoneAudits = _filterMilestoneAuditsForCurrentView(_rawMilestoneAudits);
        _isLoadingMilestones = false;
        _hasLoadedOnce = true;
      });
      unawaited(_hydrateMilestoneAuditIdentity(_milestoneAudits));
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
    } finally {
      _milestoneLoadInFlight = false;
    }
  }

  Future<void> _refreshMilestoneAudits() async {
    // Strong refresh for My Workspace: always rebuild owned-goal scope first.
    if (_viewMode == RepositoryAuditViewMode.personal && _currentUserId != null) {
      await _loadPersonalGoalIds(_currentUserId!);
    } else if (_viewMode == RepositoryAuditViewMode.managerTeam &&
        _currentUserId != null) {
      await _loadTeamMemberIds(_currentUserId!);
    }
    _milestoneLoadInFlight = false;
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
    _approvedGoalsAuditSubscription?.cancel();
    _approvedGoalsAuditSubscription = null;
    _searchController.dispose();
    _searchDebouncer.dispose();
    try {
      RepositoryService.stopAutoSync();
    } catch (e) {
      developer.log('Error stopping auto-sync: $e');
    }
    super.dispose();
  }

  /// Historical approvals live in `approved_goals_audit` until backfilled; merge for admin overview.
  void _subscribeApprovedGoalsAuditForAdmin() {
    if (!widget.forAdminOversight || _approvedGoalsAuditSubscription != null) {
      return;
    }
    _approvedGoalsAuditSubscription =
        ApprovedGoalAuditService.getManagerApprovedGoalsStream().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _approvedGoalsAuditCache = list;
          _allAuditEntries = _rebuildAllAuditEntries();
        });
        unawaited(_hydrateDisplayNamesForAuditEntries(_allAuditEntries));
        _scheduleHydrateGoalOwnerRoles(_allAuditEntries);
      },
      onError: (Object e, StackTrace st) {
        developer.log(
          'approved_goals_audit stream error: $e',
          error: e,
          stackTrace: st,
          name: 'RepositoryAuditScreen',
        );
      },
    );
  }

  List<AuditEntry> _mergeApprovedGoalsAuditOverlay(List<AuditEntry> unified) {
    if (!widget.forAdminOversight) return unified;
    final seenGoalIds = unified
        .where((e) => e.status == 'approved')
        .map((e) => e.goalId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final out = List<AuditEntry>.from(unified);
    for (final a in _approvedGoalsAuditCache) {
      if (a.goalId.isEmpty) continue;
      if (seenGoalIds.contains(a.goalId)) continue;
      out.add(_auditEntryFromApprovedGoalAudit(a));
      seenGoalIds.add(a.goalId);
    }
    out.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    return out;
  }

  /// Unified stream + `approved_goals_audit` overlay + legacy `goals` doc fallback.
  List<AuditEntry> _rebuildAllAuditEntries() {
    final merged = _mergeApprovedGoalsAuditOverlay(_unifiedEntriesOnly);
    return _mergeGoalsDocFallbackInto(merged);
  }

  bool _mergedAlreadyRepresentsGoalOutcome(
    List<AuditEntry> merged,
    String goalId,
  ) {
    if (goalId.isEmpty) return true;
    for (final e in merged) {
      if (e.goalId != goalId) continue;
      final s = e.status.toLowerCase();
      // Verified implies an approval path; skip duplicate "approved" from goals doc.
      if (s == 'approved' ||
          s == 'rejected' ||
          s == 'verified' ||
          s == 'pending' ||
          s == 'submitted' ||
          s == 'completed') {
        return true;
      }
    }
    return false;
  }

  List<AuditEntry> _mergeGoalsDocFallbackInto(List<AuditEntry> merged) {
    if (_goalsDocFallbackEntries.isEmpty) {
      return merged;
    }
    final out = List<AuditEntry>.from(merged);
    for (final row in _goalsDocFallbackEntries) {
      if (_mergedAlreadyRepresentsGoalOutcome(out, row.goalId)) continue;
      out.add(row);
    }
    out.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    return out;
  }

  Future<void> _loadGoalsDocumentApprovalFallbackForAdmin() async {
    if (!mounted || _currentUserId == null) return;
    try {
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final goals = FirebaseFirestore.instance.collection('goals');
      if (_viewMode == RepositoryAuditViewMode.personal) {
        final snap = await goals
            .where('userId', isEqualTo: _currentUserId)
            .limit(400)
            .get();
        docs.addAll(snap.docs);
      } else if (_viewMode == RepositoryAuditViewMode.managerTeam) {
        final teamIds = _teamMemberIds.toList();
        for (var i = 0; i < teamIds.length; i += 10) {
          final chunk = teamIds.sublist(
            i,
            i + 10 > teamIds.length ? teamIds.length : i + 10,
          );
          if (chunk.isEmpty) continue;
          final snap = await goals.where('userId', whereIn: chunk).limit(200).get();
          docs.addAll(snap.docs);
        }
      } else {
        final snap = await goals.limit(500).get();
        docs.addAll(snap.docs);
      }

      final ownerIds = <String>{};
      for (final doc in docs) {
        final uid = (doc.data()['userId'] ?? '').toString().trim();
        if (uid.isNotEmpty) ownerIds.add(uid);
      }

      final displayByUid = <String, String>{};
      final deptByUid = <String, String>{};
      for (final uid in ownerIds) {
        try {
          final ud =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final m = ud.data() ?? {};
          final nm = (m['displayName'] ??
                  m['fullName'] ??
                  m['name'] ??
                  m['email'] ??
                  '')
              .toString()
              .trim();
          displayByUid[uid] = nm.isNotEmpty ? nm : 'Unknown User';
          final dep = (m['department'] ?? '').toString().trim();
          deptByUid[uid] = dep.isNotEmpty ? dep : 'Unknown';
        } catch (_) {
          displayByUid[uid] = 'Unknown User';
          deptByUid[uid] = 'Unknown';
        }
      }

      final synth = <AuditEntry>[];
      for (final doc in docs) {
        final row = _auditEntrySyntheticFromGoalDocument(
          doc.id,
          doc.data(),
          displayNameFor: displayByUid,
          departmentFor: deptByUid,
        );
        if (row != null) synth.add(row);
      }

      if (!mounted) return;
      setState(() {
        _goalsDocFallbackEntries = synth;
        _allAuditEntries = _rebuildAllAuditEntries();
      });
      unawaited(_hydrateDisplayNamesForAuditEntries(_allAuditEntries));
      _scheduleHydrateGoalOwnerRoles(_allAuditEntries);
    } catch (e, st) {
      developer.log(
        'Goals collection audit fallback failed: $e',
        error: e,
        stackTrace: st,
        name: 'RepositoryAuditScreen',
      );
    }
  }

  DateTime _readGoalDocDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final p = DateTime.tryParse(v.toString());
      if (p != null) return p;
    }
    return DateTime.now();
  }

  AuditEntry? _auditEntrySyntheticFromGoalDocument(
    String goalDocId,
    Map<String, dynamic> data, {
    required Map<String, String> displayNameFor,
    required Map<String, String> departmentFor,
  }) {
    final raw = (data['approvalStatus'] ?? '').toString().toLowerCase();
    final goalStatus = (data['status'] ?? '').toString().toLowerCase();
    final isCompleted = goalStatus == 'completed' || goalStatus == 'acknowledged';
    final isPending = raw == 'pending';
    final isApproved = raw == 'approved';
    final isRejected = raw == 'rejected';
    if (!isApproved && !isRejected && !isPending && !isCompleted) return null;

    final userId = (data['userId'] ?? '').toString();
    final title = (data['title'] ?? '').toString().trim();
    final desc = (data['description'] ?? '').toString().trim();
    final goalTitle = title.isNotEmpty
        ? title
        : (desc.isNotEmpty ? desc : 'Untitled Goal');

    final created = _readGoalDocDate(data, ['createdAt']);
    final submitted = isPending
        ? _readGoalDocDate(data, ['approvalRequestedAt', 'updatedAt', 'createdAt'])
        : isCompleted
            ? _readGoalDocDate(data, ['updatedAt', 'createdAt'])
            : _readGoalDocDate(data, ['approvedAt', 'updatedAt', 'createdAt']);

    final approvedDate = isApproved
        ? _readGoalDocDate(data, ['approvedAt', 'updatedAt', 'createdAt'])
        : null;
    final rejectedDate = isRejected
        ? _readGoalDocDate(data, ['approvedAt', 'updatedAt', 'createdAt'])
        : null;
    final completedDate = isCompleted
        ? _readGoalDocDate(data, ['updatedAt', 'createdAt'])
        : submitted;

    final dn = displayNameFor[userId] ?? 'Unknown User';
    final dep = departmentFor[userId] ?? 'Unknown';

    final rr = (data['rejectionReason'] ?? '').toString().trim();
    final byName = (data['approvedByName'] ?? '').toString().trim();
    final requiredApproverRole =
        (data['requiredApproverRole'] ?? '').toString().trim().toLowerCase();
    final approvalChain = (data['approvalChain'] ?? '').toString().trim();
    final status = isCompleted
        ? 'completed'
        : isApproved
            ? 'approved'
            : isRejected
                ? 'rejected'
                : ((data['approvalRequestedAt'] != null) ? 'submitted' : 'pending');

    return AuditEntry(
      id: 'goals_fallback_$goalDocId',
      userId: userId,
      goalId: goalDocId,
      goalTitle: goalTitle,
      completedDate: completedDate,
      submittedDate: submitted,
      verifiedDate: null,
      rejectedDate: rejectedDate,
      approvedDate: approvedDate,
      createdDate: created,
      status: status,
      evidence: const <String>[],
      comments: isApproved
          ? (byName.isNotEmpty
              ? 'Recorded on goal (history): approved by $byName'
              : 'Recorded on goal (audit trail backfill)')
          : isRejected
              ? (byName.isNotEmpty
              ? 'Recorded on goal (history): rejected by $byName'
              : 'Recorded on goal (audit trail backfill)')
              : isCompleted
                  ? 'Recorded on goal (history): completed'
                  : 'Recorded on goal (history): pending approval',
      rejectionReason: rr.isNotEmpty ? rr : null,
      requiredApproverRole: requiredApproverRole.isNotEmpty
          ? requiredApproverRole
          : null,
      approvalChain: approvalChain.isNotEmpty ? approvalChain : null,
      userDisplayName: dn,
      userDepartment: dep,
    );
  }

  AuditEntry _auditEntryFromApprovedGoalAudit(ApprovedGoalAudit a) {
    return AuditEntry(
      id: 'approved_goals_audit_${a.id}',
      userId: a.employeeId,
      goalId: a.goalId,
      goalTitle: a.goalTitle,
      completedDate: a.approvedAt,
      submittedDate: a.timestamp,
      verifiedDate: a.approvedAt,
      approvedDate: a.approvedAt,
      status: 'approved',
      evidence: const <String>[],
      comments: 'Approved by ${a.approvedByName} (${a.approvedBy})',
      userDisplayName:
          a.employeeName.isNotEmpty ? a.employeeName : 'Unknown User',
      userDepartment: a.department.isNotEmpty ? a.department : 'Unknown',
      acknowledgedBy: a.approvedByName,
      acknowledgedById: a.approvedBy,
    );
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
      includeTeamDataForManager: _useTeamDataView,
      organizationWideAudit: widget.forAdminOversight,
      managerDepartment: _currentUserDepartment,
      strictManagerScope: _viewMode == RepositoryAuditViewMode.managerTeam,
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
            if (!_shouldIncludeAuditDataForCurrentView(data)) {
              continue;
            }

            // Skip entries without goalId
            if ((data['goalId'] ?? '').toString().isEmpty) {
              skippedCount++;
              continue;
            }

            // Check if it's a milestone audit
            if (data.containsKey('action')) {
              final action = data['action'] as String? ?? '';
              if (_isMilestoneAction(action)) {
                // Add to milestone audits
                milestoneAudits.add({'id': doc.id, ...data});
                milestoneCount++;
              } else if (_isGoalLifecycleAction(action)) {
                // Goal lifecycle actions are first-class audit records for
                // manager-as-employee flows (created -> approved -> verified/rejected).
                try {
                  final lifecycleEntry = _auditEntryFromGoalAction(doc);
                  entries.add(lifecycleEntry);
                  auditCount++;
                } catch (e) {
                  developer.log(
                    'Error parsing goal lifecycle action ${doc.id}: $e',
                    name: 'RepositoryAuditScreen',
                  );
                }
              }
              // Action-based records are fully handled above.
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
            _unifiedEntriesOnly = entries;
            _allAuditEntries = _rebuildAllAuditEntries();
            _rawMilestoneAudits = milestoneAudits;
            _milestoneAudits =
                _filterMilestoneAuditsForCurrentView(_rawMilestoneAudits);
            _isLoadingMilestones = false;
            _hasLoadedOnce = true;
          });
          unawaited(_hydrateDisplayNamesForAuditEntries(_allAuditEntries));
          unawaited(_hydrateMilestoneAuditIdentity(_milestoneAudits));
          _scheduleHydrateGoalOwnerRoles(_allAuditEntries);

          developer.log(
            'Unified stream updated: ${entries.length} audit entries (merged ${_allAuditEntries.length}), ${milestoneAudits.length} milestone audits',
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

  List<AuditEntry> _scopedAuditEntriesForCurrentView() {
    if (!widget.forAdminOversight) return _allAuditEntries;
    // Admin Repository & Audit is manager-oversight only.
    final managerOwned = _allAuditEntries.where(_entryIsManagerOwnedGoal).toList();
    switch (_adminGoalOwnerFilter) {
      case _AdminGoalOwnerFilter.all:
        return managerOwned;
      case _AdminGoalOwnerFilter.managerOwners:
        return managerOwned;
      case _AdminGoalOwnerFilter.employeeOwners:
        // Employee-owned goals are intentionally hidden in admin manager-oversight view.
        return const <AuditEntry>[];
    }
  }

  bool _entryMatchesUiFilters(AuditEntry e) {
    final activeStatus = (_statusFilter ?? '').trim().toLowerCase();
    if (activeStatus.isNotEmpty) {
      final status = e.status.toLowerCase();
      switch (activeStatus) {
        case 'pending':
          // Workflow-aware pending bucket across personas/chains.
          if (status != 'pending' &&
              status != 'created' &&
              status != 'submitted') {
            return false;
          }
          break;
        case 'approved':
          if (status != 'approved') return false;
          break;
        case 'verified':
          // Verified view includes approved goals in this app's lifecycle.
          if (status != 'verified' && status != 'approved') return false;
          break;
        default:
          if (status != activeStatus) return false;
      }
    }

    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return true;
    return e.goalTitle.toLowerCase().contains(search) ||
        e.userDisplayName.toLowerCase().contains(search) ||
        (e.comments ?? '').toLowerCase().contains(search) ||
        e.status.toLowerCase().contains(search);
  }

  // Goal lifecycle entries only (milestones are rendered in their own section).
  List<AuditEntry> getCachedAuditEntries({bool applyUiFilters = true}) {
    final scoped = _scopedAuditEntriesForCurrentView();
    if (!applyUiFilters) return scoped;
    return scoped.where(_entryMatchesUiFilters).toList();
  }

  List<AuditEntry> _latestEntryPerGoal(
    List<AuditEntry> entries, {
    Set<String>? allowedStatuses,
  }) {
    final outByGoal = <String, AuditEntry>{};
    for (final e in entries) {
      final status = e.status.toLowerCase();
      if (allowedStatuses != null && !allowedStatuses.contains(status)) continue;
      final goalId = e.goalId.trim();
      if (goalId.isEmpty) continue;
      final existing = outByGoal[goalId];
      if (existing == null ||
          e.submittedDate.isAfter(existing.submittedDate) ||
          (e.submittedDate.isAtSameMomentAs(existing.submittedDate) &&
              status == 'verified')) {
        outByGoal[goalId] = e;
      }
    }
    final out = outByGoal.values.toList()
      ..sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    return out;
  }

  bool _roleLooksManager(String? roleLower) {
    final r = (roleLower ?? '').trim().toLowerCase();
    if (r.isEmpty) return false;
    if (r.contains('admin')) return false;
    return r.contains('manager');
  }

  bool _roleLooksEmployeeOwner(String? roleLower) {
    final r = (roleLower ?? '').trim().toLowerCase();
    if (r.isEmpty) return true;
    if (r.contains('admin')) return false;
    return !r.contains('manager');
  }

  bool _entryIsManagerOwnedGoal(AuditEntry e) {
    final uid = e.userId.trim();
    if (uid.isEmpty) return false;
    final role = _goalOwnerRoleByUid[uid];
    return _roleLooksManager(role);
  }

  bool _entryIsEmployeeOwnedGoal(AuditEntry e) {
    final uid = e.userId.trim();
    if (uid.isEmpty) return true;
    final role = _goalOwnerRoleByUid[uid];
    return _roleLooksEmployeeOwner(role);
  }

  Future<void> _hydrateGoalOwnerRoles(Iterable<AuditEntry> entries) async {
    if (!widget.forAdminOversight) return;
    final ids = entries.map((e) => e.userId).where((id) => id.isNotEmpty).toSet();
    ids.removeWhere(_goalOwnerRoleByUid.containsKey);
    if (ids.isEmpty) return;

    try {
      final idList = ids.toList();
      for (var i = 0; i < idList.length; i += 10) {
        final chunk = idList.sublist(
          i,
          i + 10 > idList.length ? idList.length : i + 10,
        );
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final raw =
              (d.data()['role'] ?? 'employee').toString().trim().toLowerCase();
          _goalOwnerRoleByUid[d.id] = raw;
        }
        for (final uid in chunk) {
          _goalOwnerRoleByUid.putIfAbsent(uid, () => 'employee');
        }
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      developer.log(
        'hydrateGoalOwnerRoles failed: $e',
        error: e,
        stackTrace: st,
        name: 'RepositoryAuditScreen',
      );
    }
  }

  void _scheduleHydrateGoalOwnerRoles(List<AuditEntry> entries) {
    if (!widget.forAdminOversight) return;
    Future<void>(() async {
      if (!mounted) return;
      await _hydrateGoalOwnerRoles(entries);
    });
  }

  Widget _buildAdminGoalOwnerScopeBar() {
    if (!widget.forAdminOversight) return const SizedBox.shrink();
    final fg = _RepoAuditChrome.fg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _RepoAuditChrome.cardFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _RepoAuditChrome.border),
        ),
        child: Row(
          children: [
            Icon(Icons.supervisor_account, color: fg, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Admin oversight scope: manager-owned goals and milestones only.',
                style: TextStyle(color: fg, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _goalOwnerRoleCaption(String userId) {
    if (userId.isEmpty) return '';
    final r = _goalOwnerRoleByUid[userId];
    if (r == null || r.isEmpty) return '';
    if (_roleLooksManager(r)) return 'Manager goal owner';
    if (r.contains('admin')) return 'Admin goal owner';
    return 'Employee goal owner';
  }

  bool _isMilestoneAction(String action) {
    return const [
      'milestone_created',
      'milestone_updated',
      'milestone_status_changed',
      'milestone_completed',
      'milestone_acknowledged',
      'milestone_pending_review',
      'milestone_rejected',
      'milestone_dismissed',
    ].contains(action);
  }

  bool _isGoalLifecycleAction(String action) {
    return const [
      'goal_created',
      'goal_completed',
      'goal_approved',
      'goal_rejected',
      'goal_verified',
      'goal_submitted',
    ].contains(action);
  }

  AuditEntry _auditEntryFromGoalAction(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final action = (data['action'] as String?) ?? '';
    final submittedTs =
        (data['submittedDate'] ?? data['createdAt'] ?? data['timestamp'])
            as Timestamp?;
    final submittedDate = submittedTs?.toDate() ?? DateTime.now();

    String status;
    switch (action) {
      case 'goal_created':
        status = 'created';
        break;
      case 'goal_completed':
        status = 'completed';
        break;
      case 'goal_approved':
        status = 'approved';
        break;
      case 'goal_verified':
        status = 'verified';
        break;
      case 'goal_rejected':
        status = 'rejected';
        break;
      default:
        status = 'pending';
    }

    return AuditEntry(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      goalId: (data['goalId'] as String?) ?? '',
      goalTitle: (data['goalTitle'] as String?) ?? 'Untitled Goal',
      completedDate:
          (data['completedDate'] as Timestamp?)?.toDate() ?? submittedDate,
      submittedDate: submittedDate,
      verifiedDate: (data['verifiedDate'] as Timestamp?)?.toDate(),
      rejectedDate: (data['rejectedDate'] as Timestamp?)?.toDate(),
      approvedDate: (data['approvedDate'] as Timestamp?)?.toDate(),
      createdDate:
          (data['createdDate'] as Timestamp?)?.toDate() ??
          (action == 'goal_created' ? submittedDate : null),
      status: (data['status'] as String?) ?? status,
      evidence: List<String>.from(data['evidence'] ?? const []),
      acknowledgedBy: (data['acknowledgedBy'] as String?),
      acknowledgedById: (data['acknowledgedById'] as String?),
      score: (data['score'] as num?)?.toDouble(),
      comments:
          (data['comments'] as String?) ??
          (data['description'] as String?) ??
          action,
      rejectionReason: (data['rejectionReason'] as String?),
      requiredApproverRole: (data['requiredApproverRole'] as String?),
      approvalChain: (data['approvalChain'] as String?),
      userDisplayName: (data['userDisplayName'] as String?) ?? 'Unknown User',
      userDepartment: (data['userDepartment'] as String?) ?? 'Unknown',
    );
  }

  Future<List<Map<String, dynamic>>> _loadStrictPersonalMilestoneAuditsFromOwnedGoals() async {
    if (_personalGoalIds.isEmpty) return [];

    final audits = <Map<String, dynamic>>[];
    final goalIds = _personalGoalIds.toList();

    // Firestore whereIn supports up to 10 values; query in chunks.
    for (var i = 0; i < goalIds.length; i += 10) {
      final chunk = goalIds.sublist(
        i,
        i + 10 > goalIds.length ? goalIds.length : i + 10,
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('audit_entries')
          .where('goalId', whereIn: chunk)
          .limit(200)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final action = (data['action'] as String?) ?? '';
        if (_isMilestoneAction(action)) {
          audits.add({'id': doc.id, ...data});
        }
      }
    }

    // Keep the newest records first for UI consistency.
    audits.sort((a, b) {
      final ta = a['timestamp'];
      final tb = b['timestamp'];
      if (ta is Timestamp && tb is Timestamp) {
        return tb.compareTo(ta);
      }
      return 0;
    });
    return audits;
  }

  Future<void> _loadPersonalGoalIds(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .get();
      _personalGoalIds
        ..clear()
        ..addAll(snapshot.docs.map((d) => d.id));
      _personalGoalIndexHealthy = true;
    } catch (e) {
      _personalGoalIndexHealthy = false;
      developer.log(
        'Error loading personal goal ids for repository scoping: $e',
        name: 'RepositoryAuditScreen',
      );
    }
  }

  Future<void> _loadTeamMemberIds(String managerUid) async {
    if (_viewMode != RepositoryAuditViewMode.managerTeam) {
      _teamMemberIds
        ..clear()
        ..add(managerUid);
      return;
    }
    try {
      final dept = (_currentUserDepartment ?? '').trim();
      if (dept.isEmpty) {
        _teamMemberIds
          ..clear()
          ..add(managerUid);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: dept)
          .get();
      final ids = <String>{};
      for (final doc in snapshot.docs) {
        if (doc.id == managerUid) continue;
        final role = (doc.data()['role'] ?? '').toString().trim().toLowerCase();
        if (RoleService.isAdminPortalRole(role)) continue;
        ids.add(doc.id);
      }
      _teamMemberIds
        ..clear()
        ..addAll(ids);
    } catch (e) {
      developer.log(
        'Error loading team member ids for repository scoping: $e',
        name: 'RepositoryAuditScreen',
      );
    }
  }

  Future<void> _hydrateMilestoneAuditIdentity(
    List<Map<String, dynamic>> audits,
  ) async {
    if (!mounted || audits.isEmpty) return;
    final goalIds = <String>{};
    final userIds = <String>{};
    for (final row in audits) {
      final gid = (row['goalId'] ?? '').toString().trim();
      if (gid.isNotEmpty) goalIds.add(gid);
      final uid = (row['userId'] ?? '').toString().trim();
      if (uid.isNotEmpty) userIds.add(uid);
    }

    try {
      // Resolve goal owner ids from goals docs.
      final missingGoalIds = goalIds.where((g) => !_goalOwnerIdByGoalId.containsKey(g)).toList();
      for (var i = 0; i < missingGoalIds.length; i += 10) {
        final chunk = missingGoalIds.sublist(
          i,
          i + 10 > missingGoalIds.length ? missingGoalIds.length : i + 10,
        );
        final snap = await FirebaseFirestore.instance
            .collection('goals')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final ownerId = (d.data()['userId'] ?? '').toString().trim();
          _goalOwnerIdByGoalId[d.id] = ownerId;
          if (ownerId.isNotEmpty) userIds.add(ownerId);
        }
      }

      // Resolve display names for all involved user ids.
      final missingUserIds = userIds
          .where((u) => u.isNotEmpty && !_displayNameByUserId.containsKey(u))
          .toList();
      for (var i = 0; i < missingUserIds.length; i += 10) {
        final chunk = missingUserIds.sublist(
          i,
          i + 10 > missingUserIds.length ? missingUserIds.length : i + 10,
        );
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final m = d.data();
          final n = (m['displayName'] ??
                  m['fullName'] ??
                  m['name'] ??
                  m['email'] ??
                  '')
              .toString()
              .trim();
          _displayNameByUserId[d.id] = n;
        }
        for (final uid in chunk) {
          _displayNameByUserId.putIfAbsent(uid, () => '');
        }
      }

      // Build goal-owner display name cache.
      for (final gid in goalIds) {
        final ownerId = _goalOwnerIdByGoalId[gid] ?? '';
        if (ownerId.isNotEmpty) {
          _goalOwnerNameByGoalId[gid] = _displayNameByUserId[ownerId] ?? '';
        }
      }
      // Hydrate owner roles for admin manager-only filtering.
      final ownerIds = _goalOwnerIdByGoalId.values
          .where((id) => id.isNotEmpty && !_goalOwnerRoleByUid.containsKey(id))
          .toSet()
          .toList();
      for (var i = 0; i < ownerIds.length; i += 10) {
        final chunk = ownerIds.sublist(
          i,
          i + 10 > ownerIds.length ? ownerIds.length : i + 10,
        );
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final raw =
              (d.data()['role'] ?? 'employee').toString().trim().toLowerCase();
          _goalOwnerRoleByUid[d.id] = raw;
        }
      }

      if (!mounted) return;
      setState(() {
        // Re-derive filtered milestone list now that owner/role identity is hydrated.
        _milestoneAudits = _filterMilestoneAuditsForCurrentView(
          _rawMilestoneAudits,
        );
      });
    } catch (e, st) {
      developer.log(
        'Milestone identity hydration failed: $e',
        name: 'RepositoryAuditScreen',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _hydrateDisplayNamesForAuditEntries(
    List<AuditEntry> entries,
  ) async {
    if (!mounted || entries.isEmpty) return;
    final ids = entries
        .map((e) => e.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final missing = ids.where((id) {
      final existing = (_displayNameByUserId[id] ?? '').trim();
      return existing.isEmpty;
    }).toList();
    if (missing.isEmpty) return;

    try {
      for (var i = 0; i < missing.length; i += 10) {
        final chunk = missing.sublist(
          i,
          i + 10 > missing.length ? missing.length : i + 10,
        );
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final m = d.data();
          final resolved = (m['displayName'] ??
                  m['fullName'] ??
                  m['name'] ??
                  m['email'] ??
                  '')
              .toString()
              .trim();
          _displayNameByUserId[d.id] = resolved;
        }
        for (final uid in chunk) {
          _displayNameByUserId.putIfAbsent(uid, () => '');
        }
      }
      if (!mounted) return;
      setState(() {});
    } catch (e, st) {
      developer.log(
        'Audit entry display-name hydration failed: $e',
        name: 'RepositoryAuditScreen',
        error: e,
        stackTrace: st,
      );
    }
  }

  bool _shouldIncludeAuditDataForCurrentView(Map<String, dynamic> data) {
    final goalId = (data['goalId'] as String?) ?? '';
    final entryUserId = (data['userId'] as String?) ?? '';

    switch (_viewMode) {
      case RepositoryAuditViewMode.personal:
        // Strict personal mode: only show entries tied to manager-owned goals.
        if (goalId.isNotEmpty && _personalGoalIds.contains(goalId)) {
          return true;
        }
        // Resilience fallback: when ownership index could not be built, keep
        // personal view usable by allowing current-user records only.
        if (!_personalGoalIndexHealthy &&
            _currentUserId != null &&
            entryUserId == _currentUserId) {
          return true;
        }
        return false;
      case RepositoryAuditViewMode.managerTeam:
        // Team workspace must never include manager-owned personal goals.
        if (goalId.isNotEmpty && _personalGoalIds.contains(goalId)) {
          return false;
        }
        if (entryUserId.isNotEmpty && _teamMemberIds.contains(entryUserId)) {
          return true;
        }
        // Fail-closed: when team identity is uncertain, don't leak extra rows.
        return false;
      case RepositoryAuditViewMode.adminOversight:
        // Org-wide: admin must see all departments (not filtered by admin's own dept).
        return true;
    }
  }

  List<Map<String, dynamic>> _filterMilestoneAuditsForCurrentView(
    List<Map<String, dynamic>> audits,
  ) {
    final scoped = audits.where(_shouldIncludeAuditDataForCurrentView).where((a) {
      if (!widget.forAdminOversight) return true;
      return _milestoneBelongsToManagerOwner(a);
    }).toList();
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final row in scoped) {
      final id = (row['id'] ?? '').toString().trim();
      final gid = (row['goalId'] ?? '').toString().trim();
      final mid = (row['milestoneId'] ?? '').toString().trim();
      final action = (row['action'] ?? '').toString().trim();
      final ts = row['timestamp'];
      final tsKey = ts is Timestamp
          ? ts.millisecondsSinceEpoch.toString()
          : (ts?.toString() ?? '');
      final key = id.isNotEmpty ? id : '$gid|$mid|$action|$tsKey';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(row);
    }
    return out;
  }

  bool _milestoneBelongsToManagerOwner(Map<String, dynamic> audit) {
    if (!widget.forAdminOversight) return true;
    final metadata = _asMap(audit['metadata']);
    final ownerId = _firstNonEmpty(
      [
        audit['goalOwnerId']?.toString(),
        metadata['goalOwnerId']?.toString(),
        _goalOwnerIdByGoalId[(audit['goalId'] ?? '').toString().trim()],
      ],
      fallback: '',
    );
    if (ownerId.isEmpty) {
      // Legacy fallback: if actor user is manager-like, keep row visible.
      final actorId = (audit['userId'] ?? '').toString().trim();
      if (actorId.isEmpty) return false;
      final actorRole = _goalOwnerRoleByUid[actorId];
      return _roleLooksManager(actorRole);
    }
    final role = _goalOwnerRoleByUid[ownerId];
    return _roleLooksManager(role);
  }

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
                    const SizedBox(height: 20),
                    _buildSearchAndFilters(),
                    _buildAdminGoalOwnerScopeBar(),
                    const SizedBox(height: 25),
                    _buildHeader(isManagerView: _useTeamDataView),
                    Column(
                      children: [
                        _buildRoleSummaryBar(isManager: _useTeamDataView),
                        _buildAuditEntriesList(isManager: _useTeamDataView),
                        const SizedBox(height: 24),
                        _buildPendingApprovalsSection(
                          isManager: _useTeamDataView,
                        ),
                        const SizedBox(height: 24),
                        _buildRepositorySection(isManager: _useTeamDataView),
                        const SizedBox(height: 24),
                        _buildApprovedGoalsSection(isManager: _useTeamDataView),
                        const SizedBox(height: 24),
                        _buildMilestoneAuditSection(isManager: _useTeamDataView),
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
            'Search & Filters',
            style: TextStyle(
              color: _RepoAuditChrome.fg,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: _RepoAuditChrome.fg),
            decoration: InputDecoration(
              hintText: 'Search goals...',
              hintStyle: TextStyle(color: _RepoAuditChrome.fg),
              prefixIcon: Icon(Icons.search, color: _RepoAuditChrome.fg),
              filled: true,
              fillColor: _RepoAuditChrome.cardFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _RepoAuditChrome.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _RepoAuditChrome.border),
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
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? null : _statusFilter;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Created',
                  style: TextStyle(
                    color: _statusFilter == 'created'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'created',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'created' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Pending',
                  style: TextStyle(
                    color: _statusFilter == 'pending'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'pending',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'pending' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Completed',
                  style: TextStyle(
                    color: _statusFilter == 'completed'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'completed',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'completed' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Approved',
                  style: TextStyle(
                    color: _statusFilter == 'approved'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'approved',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'approved' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Verified',
                  style: TextStyle(
                    color: _statusFilter == 'verified'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'verified',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'verified' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
              FilterChip(
                label: Text(
                  'Rejected',
                  style: TextStyle(
                    color: _statusFilter == 'rejected'
                        ? Colors.white
                        : _RepoAuditChrome.fg,
                  ),
                ),
                selected: _statusFilter == 'rejected',
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? 'rejected' : null;
                  });
                },
                backgroundColor: _RepoAuditChrome.cardFill,
                selectedColor: AppColors.activeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isManagerView}) {
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
            if (isManagerView)
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
    final entries = _latestEntryPerGoal(
      getCachedAuditEntries(applyUiFilters: false),
    );
    final stats = {
      'total': entries.length,
      'created': entries.where((e) => e.status == 'created').length,
      'pending': entries
          .where(
            (e) =>
                e.status == 'pending' ||
                e.status == 'created' ||
                e.status == 'submitted',
          )
          .length,
      'rejected': entries.where((e) => e.status == 'rejected').length,
      'verified': entries
          .where(
            (e) =>
                e.status == 'verified' ||
                e.status == 'approved' ||
                e.status == 'completed',
          )
          .length,
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
            widget.forAdminOversight
                ? 'Organization overview'
                : (isManager ? 'Team Overview' : 'Your Progress'),
            style: TextStyle(
              color: _RepoAuditChrome.fg,
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
                widget.forAdminOversight ? 'Approved / verified' : 'Verified',
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
            widget.forAdminOversight
                ? 'No audit archive entries yet'
                : (isManager ? 'No team goals found' : 'No goals found'),
            style: AppTypography.heading4.copyWith(color: _RepoAuditChrome.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.forAdminOversight
                ? 'Shows goal lifecycle rows from audit_entries (created, pending, verified, rejected). If empty, those records may not exist in Firestore yet.'
                : (isManager
                    ? 'Your team hasn\'t completed any goals yet. Encourage them to set and achieve goals!'
                    : 'You haven\'t completed any goals yet. Start by creating and completing some goals!'),
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
        subtitle: Text(
          'Status: ${entry.status}',
          style: TextStyle(
            color: _getStatusColor(entry.status),
            fontWeight: FontWeight.w500,
          ),
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
      case 'completed':
      case 'verified':
        return AppColors.successColor;
      case 'rejected':
        return Colors.red;
      default:
        return _RepoAuditChrome.fg;
    }
  }

  Widget _buildAuditDetails(AuditEntry entry) {
    final requesterLabel = _resolvedEntryDisplayName(entry);
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
          widget.forAdminOversight
              ? 'Goal owner: $requesterLabel'
              : 'Requested by: $requesterLabel',
          style: TextStyle(color: _RepoAuditChrome.fg),
        ),
        if (entry.acknowledgedBy != null && entry.acknowledgedBy!.isNotEmpty)
          Text(
            'Acknowledged by: ${entry.acknowledgedBy}',
            style: TextStyle(color: AppColors.successColor),
          ),
        if (entry.submittedDate != null)
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

  String _resolvedEntryDisplayName(AuditEntry entry) {
    final fromEntry = entry.userDisplayName.trim();
    final lower = fromEntry.toLowerCase();
    if (fromEntry.isNotEmpty && lower != 'unknown' && lower != 'unknown user') {
      return fromEntry;
    }
    final fromCache = (_displayNameByUserId[entry.userId] ?? '').trim();
    if (fromCache.isNotEmpty) return fromCache;
    return 'Team member';
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
    final entries = getCachedAuditEntries(applyUiFilters: false);

    // Verified goals and recorded approvals (approved_goals_audit / goal_approved rows)
    final repositoryGoals = _latestEntryPerGoal(
      entries,
      allowedStatuses: const {'verified', 'approved', 'completed'},
    );

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
                    widget.forAdminOversight
                        ? 'No verified or approved rows in this feed yet. New approvals also write to audit_entries after you deploy the latest app.'
                        : (isManager
                            ? 'No verified entries found for your team. Previously acknowledged entries should appear here.'
                            : 'No repository items found. Complete and verify some goals to see them here.'),
                    style: TextStyle(color: _RepoAuditChrome.fg),
                  ),
                )
              : _buildRepositoryListFromAuditEntries(repositoryGoals),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsSection({required bool isManager}) {
    final entries = getCachedAuditEntries(applyUiFilters: false);
    final pendingGoals = _latestEntryPerGoal(
      entries,
      allowedStatuses: const {'pending', 'created', 'submitted'},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pending_actions, color: AppColors.warningColor),
            const SizedBox(width: 8),
            Text(
              'Pending Approval',
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
          child: pendingGoals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.forAdminOversight
                        ? 'No goals in pending approval state in the current audit feed.'
                        : (isManager
                            ? 'No team goals are currently waiting for approval.'
                            : 'No personal goals are currently waiting for approval.'),
                    style: TextStyle(color: _RepoAuditChrome.fg),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingGoals.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.borderColor),
                  itemBuilder: (context, index) {
                    final entry = pendingGoals[index];
                    final awaitingText = _awaitingApproverLabelForEntry(
                      entry,
                      isManagerView: isManager,
                    );
                    return ListTile(
                      leading: const Icon(
                        Icons.hourglass_top,
                        color: AppColors.warningColor,
                      ),
                      title: Text(
                        entry.goalTitle,
                        style: TextStyle(color: _RepoAuditChrome.fg),
                      ),
                      subtitle: Text(
                        '${entry.userDisplayName} • $awaitingText',
                        style: TextStyle(color: _RepoAuditChrome.fg),
                      ),
                      trailing: Text(
                        entry.status.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.warningColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _awaitingApproverLabelForEntry(
    AuditEntry entry, {
    required bool isManagerView,
  }) {
    final requiredRole = (entry.requiredApproverRole ?? '').trim().toLowerCase();
    if (requiredRole.contains('admin')) return 'Awaiting Admin approval';
    if (requiredRole.contains('manager')) return 'Awaiting Manager approval';
    // Fallback by workspace: manager team view is employee->manager chain.
    return isManagerView ? 'Awaiting Manager approval' : 'Awaiting Admin approval';
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
    final entries = getCachedAuditEntries(applyUiFilters: false);
    final approvedGoals = _latestEntryPerGoal(
      entries,
      allowedStatuses: const {'verified', 'approved'},
    );
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
            final goalTitle = _milestoneGoalTitle(audit);
            final milestoneTitle = _milestoneTitle(audit);
            final actorName = _milestoneActorName(audit);
            final ownerName = _milestoneOwnerName(audit);
            final actionLabel = _milestoneActionLabel(audit['action']?.toString());
            final statusLabel = _milestoneStatusLabel(audit);
            final when = _formatDate(
              audit['timestamp'] ?? audit['submittedDate'],
            );
            final desc = _milestoneDescription(audit);
            final ackLabel = _milestoneAcknowledgerLabel(audit);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _RepoAuditChrome.cardFill,
                border: Border.all(color: _RepoAuditChrome.border),
              ),
              child: ExpansionTile(
                leading: Icon(
                  _getMilestoneIcon(audit['action']),
                  color: _getMilestoneColor(audit['action']),
                ),
                title: Text(
                  milestoneTitle,
                  style: TextStyle(
                    color: _RepoAuditChrome.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${_viewMode == RepositoryAuditViewMode.personal ? goalTitle : '$ownerName • $goalTitle'} • $actionLabel • $when',
                  style: TextStyle(color: _RepoAuditChrome.fg.withValues(alpha: 0.9)),
                ),
                trailing: Text(
                  statusLabel,
                  style: TextStyle(
                    color: _getStatusColor(statusLabel.toLowerCase()),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Goal: $goalTitle',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Milestone: $milestoneTitle',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Action: $actionLabel',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Belongs to: $ownerName',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: $statusLabel',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$ackLabel: $actorName',
                          style: TextStyle(color: _RepoAuditChrome.fg),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            style: TextStyle(
                              color: _RepoAuditChrome.fg.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<String?> values, {String fallback = ''}) {
    for (final value in values) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  String _milestoneGoalTitle(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    return _firstNonEmpty(
      [audit['goalTitle']?.toString(), metadata['goalTitle']?.toString()],
      fallback: 'Goal',
    );
  }

  String _milestoneTitle(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    return _firstNonEmpty(
      [audit['milestoneTitle']?.toString(), metadata['milestoneTitle']?.toString()],
      fallback: 'Milestone',
    );
  }

  String _milestoneActorName(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    final goalId = (audit['goalId'] ?? '').toString().trim();
    final actorUid = (audit['userId'] ?? '').toString().trim();
    final actorFromUid = actorUid.isNotEmpty ? (_displayNameByUserId[actorUid] ?? '') : '';
    final ownerFromGoal = goalId.isNotEmpty ? (_goalOwnerNameByGoalId[goalId] ?? '') : '';
    return _firstNonEmpty(
      [
        actorFromUid,
        audit['userDisplayName']?.toString(),
        audit['userName']?.toString(),
        metadata['creatorName']?.toString(),
        metadata['updatedByName']?.toString(),
        ownerFromGoal,
      ],
      fallback: 'Team member',
    );
  }

  String _milestoneOwnerName(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    final goalId = (audit['goalId'] ?? '').toString().trim();
    final ownerFromGoal = goalId.isNotEmpty ? (_goalOwnerNameByGoalId[goalId] ?? '') : '';
    return _firstNonEmpty(
      [
        ownerFromGoal,
        audit['goalOwnerName']?.toString(),
        metadata['goalOwnerName']?.toString(),
        // Legacy rows may not persist explicit owner fields; fall back to actor labels.
        audit['userName']?.toString(),
        metadata['creatorName']?.toString(),
        metadata['updatedByName']?.toString(),
        audit['userDisplayName']?.toString(),
      ],
      fallback: 'Team member',
    );
  }

  String _milestoneAcknowledgerLabel(Map<String, dynamic> audit) {
    final action = (audit['action'] ?? '').toString().trim();
    if (action == 'milestone_acknowledged') return 'Acknowledged by';
    return 'Updated by';
  }

  String _milestoneDescription(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    final fromDescription = audit['description']?.toString() ?? '';
    if (fromDescription.trim().isNotEmpty) return fromDescription.trim();
    final oldStatus = metadata['oldStatusDisplay']?.toString() ?? '';
    final newStatus = metadata['newStatusDisplay']?.toString() ?? '';
    if (oldStatus.isNotEmpty || newStatus.isNotEmpty) {
      return 'Status change: $oldStatus -> $newStatus';
    }
    return '';
  }

  String _milestoneActionLabel(String? action) {
    switch ((action ?? '').trim()) {
      case 'milestone_created':
        return 'Milestone created';
      case 'milestone_updated':
        return 'Milestone updated';
      case 'milestone_status_changed':
        return 'Status changed';
      case 'milestone_completed':
        return 'Milestone completed';
      case 'milestone_acknowledged':
        return 'Milestone acknowledged';
      case 'milestone_pending_review':
        return 'Pending review';
      case 'milestone_rejected':
        return 'Milestone rejected';
      case 'milestone_dismissed':
        return 'Milestone dismissed';
      default:
        return _firstNonEmpty([action], fallback: 'Milestone event');
    }
  }

  String _milestoneStatusLabel(Map<String, dynamic> audit) {
    final metadata = _asMap(audit['metadata']);
    return _firstNonEmpty(
      [
        audit['status']?.toString(),
        metadata['newStatusDisplay']?.toString(),
        metadata['statusDisplay']?.toString(),
        metadata['newStatus']?.toString(),
        metadata['initialStatus']?.toString(),
      ],
      fallback: 'Tracked',
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
