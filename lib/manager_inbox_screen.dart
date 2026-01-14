import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/goal.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';

@immutable
class _NudgeFeedback {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String activityType;
  final String? reaction;
  final String? response;
  final String? alertId;
  final DateTime? timestamp;
    final Map<String, dynamic> metadata;

  const _NudgeFeedback({
    required this.id,
    required this.employeeId,
    required this.activityType,
    this.employeeName,
    this.reaction,
    this.response,
    this.alertId,
    this.timestamp,
      this.metadata = const {},
  });

  factory _NudgeFeedback.fromMap(Map<String, dynamic> map) {
    final metadata = (map['metadata'] as Map<String, dynamic>?) ?? {};
    return _NudgeFeedback(
      id: map['id']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      employeeName: metadata['employeeName']?.toString(),
      activityType: map['activityType']?.toString() ?? '',
      reaction: metadata['reaction']?.toString(),
      response: metadata['response']?.toString(),
      alertId: metadata['alertId']?.toString(),
      timestamp: map['timestamp'] is DateTime ? map['timestamp'] as DateTime : null,
        metadata: metadata,
    );
  }
}

class ManagerInboxScreen extends StatefulWidget {
  final bool embedded;

  const ManagerInboxScreen({super.key, this.embedded = false});

  @override
  State<ManagerInboxScreen> createState() => _ManagerInboxScreenState();
}

class _ManagerInboxScreenState extends State<ManagerInboxScreen> {
  bool _personal = false; // true: personal inbox, false: team inbox (default to Team to show approval requests)
  String? _typeFilter; // null=All, 'nudge', 'approval_request'
  bool _unreadOnly = false;
  String _search = '';
  AlertPriority? _priorityFilter;
  bool _bulkMarking = false;

  // SMART rubric local state per goalId for the review sheet
  final Map<String, int> _clarity = {};
  final Map<String, int> _measurability = {};
  final Map<String, int> _achievability = {};
  final Map<String, int> _relevance = {};
  final Map<String, int> _timeline = {};
  final Map<String, TextEditingController> _reviewNotes = {};

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _redirectIfManager();
  }

  void _showGoalReviewSheet(Alert alert) {
    final goalId = alert.relatedGoalId;
    if (goalId == null) return;
    _clarity.putIfAbsent(goalId, () => 3);
    _measurability.putIfAbsent(goalId, () => 3);
    _achievability.putIfAbsent(goalId, () => 3);
    _relevance.putIfAbsent(goalId, () => 3);
    _timeline.putIfAbsent(goalId, () => 3);
    _reviewNotes.putIfAbsent(goalId, () => TextEditingController());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('goals')
                    .doc(goalId)
                    .snapshots()
                    .handleError((error) {
                      // Silently handle errors to prevent unmount errors
                      developer.log('Error in goal stream: $error');
                    }),
                builder: (context, snap) {
                  Goal? goal;
                  if (snap.hasData && snap.data!.exists) {
                    try {
                      goal = Goal.fromFirestore(snap.data!);
                    } catch (_) {}
                  }
                  final bool finalDecision =
                      goal != null &&
                      (goal.approvalStatus == GoalApprovalStatus.approved ||
                          goal.approvalStatus == GoalApprovalStatus.rejected);
                  final bool finalApproved =
                      goal?.approvalStatus == GoalApprovalStatus.approved;
                  return ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Goal Review',
                            style: AppTypography.heading3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (goal != null) ...[
                        Text(
                          goal.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((goal.description).isNotEmpty)
                          Text(
                            goal.description,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip('Category', goal.category.name),
                            if (goal.kpa != null && goal.kpa!.isNotEmpty)
                              _chip('KPA', goal.kpa!.toUpperCase()),
                            _chip('Created', _fmtDateTime(goal.createdAt)),
                            _chip('Target', _fmtDate(goal.targetDate)),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.rule,
                            color: AppColors.activeColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SMART Review',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _scorePill(_smartTotal(goalId)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _scoreRow(
                        'Clarity (Specific)',
                        goalId,
                        _clarity,
                        '1=vague, 5=precise',
                      ),
                      _scoreRow(
                        'Measurability',
                        goalId,
                        _measurability,
                        '1=no KPI, 5=KPI+baseline+target',
                      ),
                      _scoreRow(
                        'Achievability',
                        goalId,
                        _achievability,
                        '1=unlikely, 5=realistic',
                      ),
                      _scoreRow(
                        'Relevance',
                        goalId,
                        _relevance,
                        '1=not aligned, 5=directly aligned',
                      ),
                      _scoreRow(
                        'Timeline',
                        goalId,
                        _timeline,
                        '1=no date, 5=realistic date',
                      ),
                      const SizedBox(height: 12),
                      if (finalDecision) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                (finalApproved
                                        ? AppColors.successColor
                                        : AppColors.dangerColor)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (finalApproved
                                          ? AppColors.successColor
                                          : AppColors.dangerColor)
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                finalApproved
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: finalApproved
                                    ? AppColors.successColor
                                    : AppColors.dangerColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This goal is already ${finalApproved ? 'approved' : 'rejected'}. Further approval decisions are locked.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextField(
                        controller: _reviewNotes[goalId],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText:
                              'Review note (required for Request changes/Reject)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: finalDecision
                                ? null
                                : () async {
                                    await _persistReview(
                                      goalId,
                                      decision: 'approved',
                                    );
                                    await _approveGoal(goalId);
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: finalDecision
                                ? null
                                : () async {
                                    final note =
                                        _reviewNotes[goalId]?.text.trim() ?? '';
                                    if (note.isEmpty) {
                                      await _showCenterNotice(
                                        context,
                                        'Please add a note for Request changes',
                                      );
                                      return;
                                    }
                                    await _persistReview(
                                      goalId,
                                      decision: 'changes_requested',
                                    );
                                    await _rejectGoal(goalId, reason: note);
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Request changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warningColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: finalDecision
                                ? null
                                : () async {
                                    final note =
                                        _reviewNotes[goalId]?.text.trim() ?? '';
                                    if (note.isEmpty) {
                                      await _showCenterNotice(
                                        context,
                                        'Please add a reason to reject',
                                      );
                                      return;
                                    }
                                    await _persistReview(
                                      goalId,
                                      decision: 'rejected',
                                    );
                                    await _rejectGoal(goalId, reason: note);
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dangerColor,
                              side: BorderSide(color: AppColors.dangerColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _persistReview(String goalId, {required String decision}) async {
    try {
      final reviewer = fb.FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('goals').doc(goalId).set({
        'review': {
          'smart': {
            'clarity': _clarity[goalId] ?? 3,
            'measurability': _measurability[goalId] ?? 3,
            'achievability': _achievability[goalId] ?? 3,
            'relevance': _relevance[goalId] ?? 3,
            'timeline': _timeline[goalId] ?? 3,
            'total': _smartTotal(goalId),
          },
          'decision': decision,
          'note': _reviewNotes[goalId]?.text.trim(),
          'reviewerId': reviewer?.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  int _smartTotal(String goalId) {
    return (_clarity[goalId] ?? 3) +
        (_measurability[goalId] ?? 3) +
        (_achievability[goalId] ?? 3) +
        (_relevance[goalId] ?? 3) +
        (_timeline[goalId] ?? 3);
  }

  Widget _scorePill(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Text(
        'SMART: $total/25',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _scoreRow(
    String title,
    String goalId,
    Map<String, int> map,
    String helper,
  ) {
    final current = map[goalId] ?? 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: List.generate(5, (i) {
              final score = i + 1;
              final selected = score == current;
              return ChoiceChip(
                label: Text('$score'),
                selected: selected,
                onSelected: (_) => setState(() => map[goalId] = score),
                selectedColor: AppColors.activeColor.withValues(alpha: 0.3),
                backgroundColor: AppColors.elevatedBackground,
                labelStyle: AppTypography.bodySmall.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.borderColor),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveGoal(String goalId) async {
    try {
      final manager = fb.FirebaseAuth.instance.currentUser;
      final managerName = manager?.displayName ?? 'Manager';
      await DatabaseService.approveGoal(
        goalId: goalId,
        managerId: manager?.uid ?? '',
        managerName: managerName,
      );
      if (mounted) {
        await _showCenterNotice(context, 'Goal approved');
      }
    } catch (e) {
      final message = e is StateError
          ? 'Failed to approve goal: ${e.message}'
          : 'Failed to approve goal: $e';
      if (mounted) {
        await _showCenterNotice(context, message);
      }
    }
  }

  Future<void> _rejectGoal(String goalId, {required String reason}) async {
    try {
      final manager = fb.FirebaseAuth.instance.currentUser;
      final managerName = manager?.displayName ?? 'Manager';
      await DatabaseService.rejectGoal(
        goalId: goalId,
        managerId: manager?.uid ?? '',
        managerName: managerName,
        reason: reason,
      );
      if (mounted) {
        await _showCenterNotice(context, 'Goal rejected');
      }
    } catch (e) {
      final message = e is StateError
          ? 'Failed to reject goal: ${e.message}'
          : 'Failed to reject goal: $e';
      if (mounted) {
        await _showCenterNotice(context, message);
      }
    }
  }

  Future<void> _redirectIfManager() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        if (widget.embedded) {
          // Already inside Manager Portal; stay here.
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/manager_inbox'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_inbox',
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (!context.mounted) return;
        navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
      },
      content: _buildContent(),
    );
  }

  Widget _buildContent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Please sign in to view inbox',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/khono_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: _glassCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _personal ? 'Personal Inbox' : 'Team Inbox',
                                    style: AppTypography.heading3.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Review alerts, nudges, and approvals in one place.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _bulkMarking
                                    ? null
                                    : () async {
                                        final user =
                                            FirebaseAuth.instance.currentUser;
                                        if (user == null) return;
                                        setState(() => _bulkMarking = true);
                                        await AlertService.markAllAsRead(user.uid);
                                        if (!mounted) return;
                                        setState(() => _bulkMarking = false);
                                        await _showCenterNotice(
                                          this.context,
                                          'All alerts marked as read',
                                        );
                                      },
                                icon: _bulkMarking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.mark_email_read_outlined),
                                label: const Text('Mark all as read'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildFilters(),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [Color(0x880A0F1F), Color(0x88040610)],
                  stops: [0.0, 1.0],
                ),
              ),
              child: StreamBuilder<List<Alert>>(
                stream: AlertService.getManagerInboxStream(
                  managerId: user.uid,
                  personal: _personal,
                  typeFilter: _typeFilter,
                  limit: 200,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.activeColor,
                        ),
                      ),
                    );
                  }
                  var items = snapshot.data ?? const <Alert>[];

              if (_unreadOnly) {
                items = items.where((a) => !a.isRead).toList();
              }
              if (_priorityFilter != null) {
                items = items
                    .where((a) => a.priority == _priorityFilter)
                    .toList();
              }
              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                items = items
                    .where(
                      (a) =>
                          a.title.toLowerCase().contains(q) ||
                          a.message.toLowerCase().contains(q),
                    )
                    .toList();
              }

              if (_typeFilter == 'nudge') {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ManagerRealtimeService.getNudgeFeedbackStream(
                    managerId: user.uid,
                    managerName: user.displayName,
                    limit: 200,
                  ),
                  builder: (context, fbSnap) {
                    final feedbackMaps = fbSnap.data ?? const <Map<String, dynamic>>[];
                    final rawFeedback = feedbackMaps
                        .map(_NudgeFeedback.fromMap)
                        .toList();

                    final managerNameLower =
                        (user.displayName ?? '').toLowerCase().trim();
                    final feedback = rawFeedback.where((f) {
                      final meta = f.metadata;
                      final mid = meta['managerId']?.toString();
                      final mname = meta['managerName']?.toString().toLowerCase().trim();
                      final matchesId = mid != null && mid == user.uid;
                      final matchesName = managerNameLower.isNotEmpty &&
                          mname != null &&
                          mname == managerNameLower;
                      return matchesId || matchesName;
                    }).toList();

                    final hPad = AppSpacing.screenPadding.left;
                    final widgets = <Widget>[];

                    widgets.add(
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          AppSpacing.lg,
                          hPad,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          'Nudge Feedback',
                          style: AppTypography.heading4.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );

                    if (feedback.isEmpty) {
                      widgets.add(
                        Padding(
                          padding: AppSpacing.screenPadding,
                          child: Text(
                            'No replies or reactions yet.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      );
                    } else {
                      widgets.addAll(
                        feedback.map((f) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: hPad,
                                vertical: AppSpacing.xs,
                              ),
                              child: _buildNudgeFeedbackCard(f),
                            )),
                      );
                    }

                    if (items.isNotEmpty) {
                      widgets.add(
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            hPad,
                            AppSpacing.lg,
                            hPad,
                            AppSpacing.sm,
                          ),
                          child: Text(
                            'Manager Nudges',
                            style: AppTypography.heading4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                      widgets.addAll(
                        items.map((a) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: hPad,
                                vertical: AppSpacing.xs,
                              ),
                              child: _buildInboxCard(a),
                            )),
                      );
                    }

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: widgets,
                    );
                  },
                );
              }

                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: Text(
                          'No inbox items match your filters.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: AppSpacing.screenPadding,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _buildInboxCard(items[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _inboxChoiceChip(
              label: 'Personal',
              selected: _personal,
              onSelected: () => setState(() => _personal = true),
            ),
            const SizedBox(width: 8),
            _inboxChoiceChip(
              label: 'Team',
              selected: !_personal,
              onSelected: () => setState(() => _personal = false),
            ),
            const Spacer(),
            _inboxFilterChip(
              label: 'Unread',
              selected: _unreadOnly,
              onSelected: (v) => setState(() => _unreadOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _inboxChoiceChip(
              label: 'All',
              selected: _typeFilter == null,
              onSelected: () => setState(() => _typeFilter = null),
            ),
            _inboxChoiceChip(
              label: 'Alerts',
              selected: _typeFilter == 'alert',
              onSelected: () => setState(() => _typeFilter = 'alert'),
            ),
            _inboxChoiceChip(
              label: 'Nudges',
              selected: _typeFilter == 'nudge',
              onSelected: () => setState(() => _typeFilter = 'nudge'),
            ),
            _inboxChoiceChip(
              label: 'Approvals',
              selected: _typeFilter == 'approval_request',
              onSelected: () =>
                  setState(() => _typeFilter = 'approval_request'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: _glassFieldColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: _glassCardDecoration(radius: 8),
              child: DropdownButton<AlertPriority?>(
                value: _priorityFilter,
                underline: const SizedBox(),
                hint: Text(
                  'Priority',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                dropdownColor: Colors.black.withValues(alpha: 0.9),
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                onChanged: (p) => setState(() => _priorityFilter = p),
                items: [
                  const DropdownMenuItem<AlertPriority?>(
                    value: null,
                    child: Text('All Priorities'),
                  ),
                  ...AlertPriority.values.map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name.toUpperCase()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInboxCard(Alert alert) {
    final color = _getAlertColor(alert.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(
        borderColor: alert.isRead
            ? Colors.white.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/red_bell.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!alert.isRead)
                Image.asset(
                  'assets/Email_Notification/Notification_Red_White.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.message,
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _getTimeAgo(alert.createdAt),
                style: AppTypography.bodySmall.copyWith(color: Colors.white54),
              ),
              const SizedBox(width: 8),
              if (alert.type == AlertType.goalApprovalRequested)
                TextButton.icon(
                  onPressed: () => _showGoalReviewSheet(alert),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Goal'),
                )
              else if (alert.type == AlertType.managerNudge &&
                  alert.relatedGoalId != null &&
                  alert.relatedGoalId!.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/manager_portal',
                      arguments: {
                        'initialRoute': '/manager_review_team_dashboard',
                        'goalId': alert.relatedGoalId,
                      },
                    );
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('View Goal'),
                ),
              ]
              else if (alert.type == AlertType.goalMilestoneCompleted ||
                  alert.type == AlertType.goalCreated ||
                  alert.type == AlertType.goalCompleted ||
                  alert.type == AlertType.goalDueSoon ||
                  alert.type == AlertType.goalOverdue)
                TextButton.icon(
                  onPressed: () {
                    if (alert.relatedGoalId != null) {
                      Navigator.pushNamed(
                        context,
                        '/manager_portal',
                        arguments: {
                          'initialRoute': '/manager_review_team_dashboard',
                          'goalId': alert.relatedGoalId,
                        },
                      );
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('View Goal'),
                )
              else if (alert.type == AlertType.badgeEarned ||
                  alert.type == AlertType.achievementUnlocked)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/manager_portal',
                      arguments: {'initialRoute': '/manager_badges_points'},
                    );
                  },
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('View Badges'),
                )
              else if (alert.actionText != null && alert.actionRoute != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      alert.actionRoute!,
                      arguments: alert.relatedGoalId != null
                          ? {'goalId': alert.relatedGoalId}
                          : null,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(alert.actionText!),
                )
              else if (alert.actionText != null)
                TextButton(
                  onPressed: () {
                    // Try to navigate using common routes based on action text
                    final actionLower = alert.actionText!.toLowerCase();
                    if (actionLower.contains('badge') ||
                        actionLower.contains('achievement')) {
                      Navigator.pushNamed(
                        context,
                        '/manager_portal',
                        arguments: {'initialRoute': '/manager_badges_points'},
                      );
                    } else if (actionLower.contains('goal')) {
                      if (alert.relatedGoalId != null) {
                        Navigator.pushNamed(
                          context,
                          '/manager_portal',
                          arguments: {
                            'initialRoute': '/manager_review_team_dashboard',
                            'goalId': alert.relatedGoalId,
                          },
                        );
                      }
                    } else if (actionLower.contains('leaderboard')) {
                      Navigator.pushNamed(
                        context,
                        '/manager_portal',
                        arguments: {'initialRoute': '/manager_leaderboard'},
                      );
                    }
                  },
                  child: Text(alert.actionText!),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Mark read',
                onPressed: () => AlertService.markAsRead(alert.id),
                icon: const Icon(Icons.mark_email_read_outlined),
                color: AppColors.textSecondary,
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => AlertService.dismissAlert(alert.id),
                icon: const Icon(Icons.close),
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeFeedbackCard(_NudgeFeedback fb) {
    final isReaction = fb.activityType == 'nudge_reaction';
    final chipLabel = isReaction ? 'Reaction' : 'Reply';
    final chipColor =
        isReaction ? AppColors.infoColor : AppColors.activeColor;
    final title = fb.employeeName?.isNotEmpty == true
        ? fb.employeeName!
        : 'Employee ${fb.employeeId.substring(0, fb.employeeId.length >= 6 ? 6 : fb.employeeId.length)}';
    final message = isReaction
        ? fb.reaction ?? 'Reaction'
        : fb.response ?? 'Response';

    return Container(
      decoration: _glassCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: chipColor.withValues(alpha: 0.15),
                child: Icon(
                  isReaction ? Icons.emoji_emotions_outlined : Icons.reply,
                  color: chipColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: chipColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  chipLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                fb.timestamp != null ? _getTimeAgo(fb.timestamp!) : '',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (fb.alertId != null && fb.alertId!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '#${fb.alertId!.substring(0, fb.alertId!.length >= 6 ? 6 : fb.alertId!.length)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  ChoiceChip _inboxChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.activeColor.withValues(alpha: 0.35),
      backgroundColor: _glassFieldColor,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  FilterChip _inboxFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.warningColor.withValues(alpha: 0.3),
      checkmarkColor: Colors.white,
      backgroundColor: _glassFieldColor,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: Colors.white,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  BoxDecoration _glassCardDecoration({double radius = 12, Color? borderColor}) {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.15),
      ),
    );
  }

  Color get _glassFieldColor => Colors.black.withValues(alpha: 0.35);

  Color _getAlertColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return AppColors.infoColor;
      case AlertPriority.medium:
        return AppColors.activeColor;
      case AlertPriority.high:
        return AppColors.warningColor;
      case AlertPriority.urgent:
        return AppColors.dangerColor;
    }
  }
}
