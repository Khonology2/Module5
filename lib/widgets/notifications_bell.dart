import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';

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

        return InkWell(
          onTap: onTap ?? openAlerts,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/blue_bell.png',
                  width: 38,
                  height: 38,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 38,
                  ),
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
  }
}
