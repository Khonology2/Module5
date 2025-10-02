import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/models/alert.dart';

class AlertsNudgesScreen extends StatefulWidget {
  const AlertsNudgesScreen({super.key});

  @override
  State<AlertsNudgesScreen> createState() => _AlertsNudgesScreenState();
}

class _AlertsNudgesScreenState extends State<AlertsNudgesScreen> {
  @override
  void initState() {
    super.initState();
    // Check for new alerts when screen loads
    AlertService.checkAndCreateGoalAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Alerts & Nudges',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/alerts_nudges',
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        await AuthService().signOut();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sign_in',
          (route) => false,
        );
      },
      content: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundColor,
              AppColors.backgroundColor.withOpacity(0.9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
      child: StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
            builder: (context, roleSnapshot) {
              final role = roleSnapshot.data;
              
          if (role == null) {
            return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                  ),
                );
              }

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                return Center(
                  child: Text(
                    'Please sign in to view alerts',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  Text(
                    'Alerts & Nudges',
                    style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSmartAlertsCard(),
                  const SizedBox(height: AppSpacing.lg),
                  StreamBuilder<List<Alert>>(
                    stream: AlertService.getUserAlertsStream(user.uid),
                    builder: (context, alertsSnapshot) {
                      if (alertsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                          ),
                        );
                      }

                      if (alertsSnapshot.hasError) {
                        final errorMessage = alertsSnapshot.error.toString();
                        
                        // Check if it's a permission error
                        if (errorMessage.contains('permission-denied') || 
                            errorMessage.contains('Missing or insufficient permissions')) {
                          return _buildPermissionErrorState();
                        }
                        
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.dangerColor,
                              ),
              const SizedBox(height: 16),
                              Text(
                                'Error loading alerts',
                                style: AppTypography.heading4.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final alerts = alertsSnapshot.data ?? [];
                      
                      return Column(
                        children: [
                          _buildAlertSummary(alerts),
                          const SizedBox(height: AppSpacing.lg),
                          _buildAlertsList(alerts),
                        ],
                      );
                    },
                  ),
            ],
          );
        },
          ),
        ),
      ),
    );
  }

  Widget _buildSmartAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.activeColor.withOpacity(0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.activeColor.withOpacity(0.1),
            AppColors.elevatedBackground,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.activeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: AppColors.activeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
              Text(
                    'Smart Alerts',
                    style: AppTypography.heading4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.activeColor.withOpacity(0.3)),
                ),
                child: Text(
                  'AI POWERED',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Personalized notifications based on your goals, habits, and progress patterns',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSummary(List<Alert> alerts) {
    final unreadCount = alerts.where((alert) => !alert.isRead).length;
    final urgentCount = alerts.where((alert) => alert.priority == AlertPriority.urgent).length;
    final dueSoonCount = alerts.where((alert) => alert.type == AlertType.goalDueSoon).length;
    final overdueCount = alerts.where((alert) => alert.type == AlertType.goalOverdue).length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryChip(
            'Unread',
            unreadCount.toString(),
            AppColors.activeColor,
            Icons.notifications,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Urgent',
            urgentCount.toString(),
            AppColors.dangerColor,
            Icons.priority_high,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Due Soon',
            dueSoonCount.toString(),
            AppColors.warningColor,
            Icons.schedule,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Overdue',
            overdueCount.toString(),
            AppColors.dangerColor,
            Icons.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: AppTypography.heading4.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(List<Alert> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyAlertsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Alerts',
              style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
            ),
            if (alerts.any((alert) => !alert.isRead))
              TextButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await AlertService.markAllAsRead(user.uid);
                  }
                },
                child: Text(
                  'Mark All Read',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...alerts.map((alert) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildAlertCard(alert),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
      children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Alerts Yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications about your goals, achievements, and team updates here.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/my_goal_workspace');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    final alertColor = _getAlertColor(alert.type, alert.priority);
    final alertIcon = _getAlertIcon(alert.type);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: alert.isRead 
              ? AppColors.borderColor 
              : alertColor.withOpacity(0.3),
          width: alert.isRead ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(alertIcon, color: alertColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                            decoration: BoxDecoration(
                              color: AppColors.activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                      Text(
                          _getTimeAgo(alert.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (alert.fromUserName != null) ...[
                          Text(
                            ' • from ${alert.fromUserName}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: alertColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.priority.name.toUpperCase(),
                            style: AppTypography.bodySmall.copyWith(
                              color: alertColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                        ),
                      ),
                    ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert.actionText != null) ...[
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                    onPressed: () async {
                      // Mark as read when action is taken
                      await AlertService.markAsRead(alert.id);
                      
                      // Navigate to action route if provided
                      if (alert.actionRoute != null) {
                        Navigator.pushNamed(context, alert.actionRoute!);
                      }
                    },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: alertColor,
                      foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                    child: Text(alert.actionText!),
                  ),
                ),
                const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                    onPressed: () async {
                      await AlertService.dismissAlert(alert.id);
                    },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getAlertColor(AlertType type, AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return AppColors.dangerColor;
      case AlertPriority.high:
        return AppColors.warningColor;
      case AlertPriority.medium:
        return AppColors.activeColor;
      case AlertPriority.low:
        return AppColors.successColor;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.goalCreated:
        return Icons.flag;
      case AlertType.goalCompleted:
        return Icons.check_circle;
      case AlertType.goalDueSoon:
        return Icons.schedule;
      case AlertType.goalOverdue:
        return Icons.warning;
      case AlertType.pointsEarned:
        return Icons.stars;
      case AlertType.levelUp:
        return Icons.trending_up;
      case AlertType.badgeEarned:
        return Icons.workspace_premium;
      case AlertType.teamAssigned:
        return Icons.group_add;
      case AlertType.managerNudge:
        return Icons.notifications_active;
      case AlertType.achievementUnlocked:
        return Icons.emoji_events;
      case AlertType.streakMilestone:
        return Icons.local_fire_department;
      case AlertType.deadlineReminder:
        return Icons.access_time;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildPermissionErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            size: 48,
            color: AppColors.warningColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Alerts Setup Required',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The alerts system needs to be configured by your administrator. In the meantime, you can still use all other features of the app.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You\'ll be notified when alerts are available!',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}

// Drawer removed; persistent sidebar via MainLayout

