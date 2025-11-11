import 'package:flutter/material.dart';
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

class ManagerInboxScreen extends StatefulWidget {
  final bool embedded;

  const ManagerInboxScreen({super.key, this.embedded = false});

  @override
  State<ManagerInboxScreen> createState() => _ManagerInboxScreenState();
}

class _ManagerInboxScreenState extends State<ManagerInboxScreen> {
  bool _personal = true; // true: personal inbox, false: team inbox
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
                stream: FirebaseFirestore.instance.collection('goals').doc(goalId).snapshots(),
                builder: (context, snap) {
                  Goal? goal;
                  if (snap.hasData && snap.data!.exists) {
                    try { goal = Goal.fromFirestore(snap.data!); } catch (_) {}
                  }
                  return ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        children: [
                          Text('Goal Review', style: AppTypography.heading3.copyWith(color: AppColors.textPrimary)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            color: AppColors.textSecondary,
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (goal != null) ...[
                        Text(goal.title, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if ((goal.description).isNotEmpty)
                          Text(goal.description, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _chip('Category', goal.category.name),
                          if (goal.kpa != null && goal.kpa!.isNotEmpty) _chip('KPA', goal.kpa!.toUpperCase()),
                          _chip('Created', _fmtDateTime(goal.createdAt)),
                          _chip('Target', _fmtDate(goal.targetDate)),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Icon(Icons.rule, color: AppColors.activeColor, size: 18),
                          const SizedBox(width: 8),
                          Text('SMART Review', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          _scorePill(_smartTotal(goalId)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _scoreRow('Clarity (Specific)', goalId, _clarity, '1=vague, 5=precise'),
                      _scoreRow('Measurability', goalId, _measurability, '1=no KPI, 5=KPI+baseline+target'),
                      _scoreRow('Achievability', goalId, _achievability, '1=unlikely, 5=realistic'),
                      _scoreRow('Relevance', goalId, _relevance, '1=not aligned, 5=directly aligned'),
                      _scoreRow('Timeline', goalId, _timeline, '1=no date, 5=realistic date'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewNotes[goalId],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Review note (required for Request changes/Reject)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _persistReview(goalId, decision: 'approved');
                              await _approveGoal(goalId);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.successColor, foregroundColor: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final note = _reviewNotes[goalId]?.text.trim() ?? '';
                              if (note.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a note for Request changes')));
                                return;
                              }
                              await _persistReview(goalId, decision: 'changes_requested');
                              await _rejectGoal(goalId, reason: note);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Request changes'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warningColor, foregroundColor: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final note = _reviewNotes[goalId]?.text.trim() ?? '';
                              if (note.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a reason to reject')));
                                return;
                              }
                              await _persistReview(goalId, decision: 'rejected');
                              await _rejectGoal(goalId, reason: note);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerColor, side: BorderSide(color: AppColors.dangerColor)),
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
        }
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  int _smartTotal(String goalId) {
    return (_clarity[goalId] ?? 3) + (_measurability[goalId] ?? 3) + (_achievability[goalId] ?? 3) + (_relevance[goalId] ?? 3) + (_timeline[goalId] ?? 3);
  }

  Widget _scorePill(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Text('SMART: $total/25', style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
    );
  }

  Widget _scoreRow(String title, String goalId, Map<String, int> map, String helper) {
    final current = map[goalId] ?? 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(helper, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
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
                labelStyle: AppTypography.bodySmall.copyWith(color: selected ? AppColors.textPrimary : AppColors.textSecondary),
                shape: StadiumBorder(side: BorderSide(color: AppColors.borderColor)),
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
          Text('$label: ', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve goal: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject goal: $e')),
        );
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
      title: 'Inbox',
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
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundColor,
            AppColors.backgroundColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Inbox',
                        style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _bulkMarking
                          ? null
                          : () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;
                              setState(() => _bulkMarking = true);
                              await AlertService.markAllAsRead(user.uid);
                              if (!mounted) return;
                              setState(() => _bulkMarking = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All alerts marked as read')),
                              );
                            },
                      icon: _bulkMarking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
          Expanded(
            child: StreamBuilder<List<Alert>>(
              stream: AlertService.getManagerInboxStream(
                managerId: user.uid,
                personal: _personal,
                // Apply the selected type filter directly ('alert' | 'nudge' | 'approval_request' | null)
                typeFilter: _typeFilter,
                limit: 200,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                    ),
                  );
                }
                var items = snapshot.data ?? const <Alert>[];

                if (_unreadOnly) {
                  items = items.where((a) => !a.isRead).toList();
                }
                if (_priorityFilter != null) {
                  items = items.where((a) => a.priority == _priorityFilter).toList();
                }
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  items = items.where((a) =>
                    a.title.toLowerCase().contains(q) ||
                    a.message.toLowerCase().contains(q)
                  ).toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Text(
                        'No items',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: AppSpacing.screenPadding,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _buildInboxCard(items[i]),
                );
              },
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
            ChoiceChip(
              label: const Text('Personal'),
              selected: _personal,
              onSelected: (_) => setState(() => _personal = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Team'),
              selected: !_personal,
              onSelected: (_) => setState(() => _personal = false),
            ),
            const Spacer(),
            FilterChip(
              label: const Text('Unread'),
              selected: _unreadOnly,
              onSelected: (v) => setState(() => _unreadOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _typeFilter == null,
              onSelected: (_) => setState(() => _typeFilter = null),
            ),
            ChoiceChip(
              label: const Text('Alerts'),
              selected: _typeFilter == 'alert',
              onSelected: (_) => setState(() => _typeFilter = 'alert'),
            ),
            ChoiceChip(
              label: const Text('Nudges'),
              selected: _typeFilter == 'nudge',
              onSelected: (_) => setState(() => _typeFilter = 'nudge'),
            ),
            ChoiceChip(
              label: const Text('Approvals'),
              selected: _typeFilter == 'approval_request',
              onSelected: (_) => setState(() => _typeFilter = 'approval_request'),
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
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: DropdownButton<AlertPriority?>(
                value: _priorityFilter,
                underline: const SizedBox(),
                hint: Text('Priority', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                onChanged: (p) => setState(() => _priorityFilter = p),
                items: [
                  const DropdownMenuItem<AlertPriority?>(value: null, child: Text('All Priorities')),
                  ...AlertPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))),
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
    final icon = _getAlertIcon(alert.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isRead ? AppColors.borderColor : color.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
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
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _getTimeAgo(alert.createdAt),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              if (alert.type == AlertType.goalApprovalRequested)
                TextButton.icon(
                  onPressed: () => _showGoalReviewSheet(alert),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Goal'),
                )
              else if (alert.actionText != null)
                TextButton(
                  onPressed: () {},
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
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.goalCreated:
        return Icons.flag_outlined;
      case AlertType.goalCompleted:
        return Icons.check_circle_outline;
      case AlertType.goalDueSoon:
        return Icons.schedule_outlined;
      case AlertType.goalOverdue:
        return Icons.priority_high_outlined;
      case AlertType.inactivity:
        return Icons.hourglass_empty_outlined;
      case AlertType.milestoneRisk:
        return Icons.warning_amber_outlined;
      case AlertType.badgeEarned:
        return Icons.emoji_events_outlined;
      case AlertType.pointsEarned:
        return Icons.star_border;
      case AlertType.teamGoalAvailable:
        return Icons.group_add_outlined;
      case AlertType.employeeJoinedTeamGoal:
        return Icons.group_outlined;
      case AlertType.teamAssigned:
        return Icons.group_outlined;
      case AlertType.managerNudge:
        return Icons.campaign_outlined;
      case AlertType.achievementUnlocked:
        return Icons.celebration_outlined;
      case AlertType.levelUp:
        return Icons.rocket_launch_outlined;
      case AlertType.streakMilestone:
        return Icons.whatshot_outlined;
      case AlertType.deadlineReminder:
        return Icons.alarm_outlined;
      case AlertType.seasonJoined:
        return Icons.event_available_outlined;
      case AlertType.seasonCompleted:
        return Icons.emoji_events_outlined;
      case AlertType.seasonProgressUpdate:
        return Icons.trending_up_outlined;
      case AlertType.goalApprovalRequested:
        return Icons.fact_check_outlined;
      case AlertType.goalApprovalApproved:
        return Icons.thumb_up_alt_outlined;
      case AlertType.goalApprovalRejected:
        return Icons.thumb_down_alt_outlined;
    }
  }
}
