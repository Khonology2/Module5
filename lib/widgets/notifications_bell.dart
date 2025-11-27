import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';

class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key});

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateAnimation(bool hasUnread) {
    if (hasUnread) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

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

        // Update animation based on unread status
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateAnimation(hasUnread);
        });

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
          onTap: openAlerts,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3652),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: AnimatedBuilder(
                  animation: _opacityAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: hasUnread ? _opacityAnimation.value : 1.0,
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 18,
                      ),
                    );
                  },
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
