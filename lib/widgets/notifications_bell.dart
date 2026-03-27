import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key, this.onTap});

  /// When set, this callback is used instead of the default role-based navigation (e.g. admin portal can route to admin inbox).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Alert>>(
      stream: AlertService.getUserAlertsStream(user.uid),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <Alert>[];
        final unreadCount = alerts.where((a) => !a.isRead).length;
        final hasUnread = unreadCount > 0;

        void openAlerts() {
          final role = RoleService.instance.cachedRole;
          final route = role == 'manager'
              ? '/manager_alerts_nudges'
              : '/alerts_nudges';
          final current = ModalRoute.of(context)?.settings.name;
          if (current != route) {
            Navigator.pushNamed(context, route);
          }
        }

        return ValueListenableBuilder<bool>(
          valueListenable: employeeDashboardLightModeNotifier,
          builder: (context, light, _) {
            final bg = light ? Colors.white : const Color(0xFF2A3652);
            final iconColor = light ? Colors.black : Colors.white;
            final borderColor =
                light ? const Color(0x33000000) : const Color(0x1FFFFFFF);
            return InkWell(
              onTap: onTap ?? openAlerts,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
              if (hasUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
