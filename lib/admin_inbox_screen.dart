import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class AdminInboxScreen extends StatefulWidget {
  final bool embedded;

  const AdminInboxScreen({super.key, this.embedded = false});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  late final Stream<List<EmployeeData>> _managersStream;

  @override
  void initState() {
    super.initState();
    _managersStream = ManagerRealtimeService.getManagersDataStream();
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildAlertCard(Alert alert) {
    final color = _getAlertColor(alert.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                child: Icon(Icons.notifications_outlined, color: color, size: 20),
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
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _getTimeAgo(alert.createdAt),
                style: AppTypography.bodySmall.copyWith(color: Colors.white54),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Mark read',
                onPressed: () => AlertService.markAsRead(alert.id),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                color: AppColors.textSecondary,
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => AlertService.dismissAlert(alert.id),
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = StreamBuilder<List<EmployeeData>>(
      stream: _managersStream,
      builder: (context, managersSnap) {
        if (managersSnap.connectionState == ConnectionState.waiting &&
            !managersSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }
        final managers = managersSnap.data ?? [];
        if (managers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'No managers yet',
                  style: AppTypography.heading4.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inbox content from all managers will appear here.',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: _glassCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Inbox',
                    style: AppTypography.heading3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All inbox content from manager users across the organization.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...managers.map((manager) {
              final uid = manager.profile.uid;
              final name = manager.profile.displayName.isNotEmpty
                  ? manager.profile.displayName
                  : 'Manager';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: _glassCardDecoration(),
                child: ExpansionTile(
                  initiallyExpanded: managers.length <= 5,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    name,
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    StreamBuilder<List<Alert>>(
                      stream: AlertService.getUserAlertsStream(uid),
                      builder: (context, alertsSnap) {
                        if (alertsSnap.connectionState ==
                                ConnectionState.waiting &&
                            !alertsSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.activeColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final alerts = alertsSnap.data ?? [];
                        if (alerts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No alerts',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: alerts.map(_buildAlertCard).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'Inbox',
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Color(0x880A0F1F), Color(0x88040610)],
            stops: [0.0, 1.0],
          ),
        ),
        child: body,
      ),
    );
  }
}
