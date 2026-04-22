import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/utils/firestore_safe.dart';

class UpcomingGoalsListScreen extends StatelessWidget {
  const UpcomingGoalsListScreen({super.key});

  Stream<List<Goal>> _getUpcomingGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirestoreSafe.stream(
      FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
    ).map((snapshot) {
          final goals = snapshot.docs
              .map((doc) => Goal.fromFirestore(doc))
              .where(
                (g) =>
                    g.approvalStatus == GoalApprovalStatus.approved &&
                    g.status != GoalStatus.completed &&
                    g.progress < 100,
              )
              .toList();

          goals.sort((a, b) => a.targetDate.compareTo(b.targetDate));
          return goals;
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, roleSnapshot) {
        final role =
            roleSnapshot.data ?? RoleService.instance.cachedRole ?? 'employee';
        final items = SidebarConfig.getItemsForRole(role);
        return AppScaffold(
          title: 'Upcoming Goals',
          showAppBar: false,
          items: items,
          currentRouteName: '/upcoming_goals_list',
          onNavigate: (route) {
            final current = ModalRoute.of(context)?.settings.name;
            if (current != route) {
              Navigator.pushNamed(context, route);
            }
          },
          onLogout: () async {
            final navigator = Navigator.of(context);
            await AuthService().signOut();
            navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
          },
          content: StreamBuilder<List<Goal>>(
            stream: _getUpcomingGoalsStream(),
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
              final goals = snapshot.data ?? const <Goal>[];
              return AppComponents.backgroundWithImage(
                imagePath: 'assets/khono_bg.png',
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.pushReplacementNamed(
                              context,
                              '/employee_dashboard',
                            );
                          },
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Image.asset(
                                'assets/BackButton-Red.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.builder(
                          padding: AppSpacing.screenPadding,
                          itemCount: goals.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: Text(
                                  'All Upcoming Goals',
                                  style: AppTypography.heading2.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                            final goal = goals[index - 1];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _GoalListItem(goal: goal),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GoalListItem extends StatelessWidget {
  final Goal goal;
  const _GoalListItem({required this.goal});

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

  Color _priorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysUntilDeadline = goal.targetDate.difference(now).inDays;
    final isOverdue = daysUntilDeadline < 0;
    String deadlineText;
    Color deadlineColor = AppColors.textSecondary;

    if (isOverdue) {
      deadlineText =
          'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline == 1) {
      deadlineText = 'Due tomorrow';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline <= 7) {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = AppColors.warningColor;
    } else {
      deadlineText = 'Due in $daysUntilDeadline days';
    }

    return InkWell(
      onTap: () async {
        if (goal.approvalStatus != GoalApprovalStatus.approved) {
          await _showCenterNotice(context, 'Awaiting manager approval.');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GoalDetailScreen(goal: goal)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor(goal.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _priorityColor(
                        goal.priority,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    goal.priority.name.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: _priorityColor(goal.priority),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              deadlineText,
              style: AppTypography.muted.copyWith(color: deadlineColor),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (goal.progress / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              '${goal.progress}% Complete',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
