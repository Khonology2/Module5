import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, this.onTap});

  /// When set, this callback is used instead of the default role-based navigation (e.g. admin portal can route to admin inbox).
  final VoidCallback? onTap;

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

  void _openAlerts(BuildContext context) {
    Navigator.pushNamed(context, '/alerts_nudges');
  }

  Future<bool> _isProfileIncomplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userProfile = await DatabaseService.getUserProfile(user.uid);
      final onboardingData = await DatabaseService.getOnboardingData(
        userId: user.uid,
        email: user.email,
      );

      final fullName = onboardingData['fullName'] ?? userProfile.displayName;
      final jobTitle = onboardingData['designation'] ?? userProfile.jobTitle;
      final department = userProfile.department;
      final email = userProfile.email;

      return fullName.trim().isEmpty ||
          jobTitle.trim().isEmpty ||
          department.trim().isEmpty ||
          email.trim().isEmpty;
    } catch (_) {
      return false;
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
        final unreadAlertsCount = alerts.where((a) => !a.isRead).length;

        return FutureBuilder<bool>(
          future: _isProfileIncomplete(),
          builder: (context, profileSnapshot) {
            // Include profile incomplete as an unread alert
            final profileIncomplete = profileSnapshot.data ?? false;
            final unreadCount = unreadAlertsCount + (profileIncomplete ? 1 : 0);
            final hasUnread = unreadCount > 0;
            _updateAnimation(hasUnread);

            return ValueListenableBuilder<bool>(
              valueListenable: employeeDashboardLightModeNotifier,
              builder: (context, light, _) {
                final bg = light ? Colors.white : const Color(0xFF2A3652);
                final iconColor = light ? Colors.black : Colors.white;
                final borderColor =
                    light ? const Color(0x33000000) : const Color(0x1FFFFFFF);

                return InkWell(
                  onTap: widget.onTap ?? () => _openAlerts(context),
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
                          child: FadeTransition(
                            opacity: _opacityAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.activeColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x1FFFFFFF)),
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
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
      },
    );
  }
}
