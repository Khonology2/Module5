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
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
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
                // Treat generic alerts as default (null)
                typeFilter: _typeFilter == 'alert' ? null : _typeFilter,
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
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
              if (alert.actionText != null)
                TextButton(
                  onPressed: () {
                    // TODO: navigate using actionRoute/actionData when integrated
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
