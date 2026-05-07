import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_typography.dart';

class AppContentHeader extends StatelessWidget {
  const AppContentHeader({
    super.key,
    required this.title,
    required this.actions,
    this.showGreeting = false,
    this.textColor = Colors.white,
  });

  static const double kHeaderHeight = 64;

  final String title;
  final Widget actions;
  final bool showGreeting;
  final Color textColor;

  String _resolveUserName() {
    final user = FirebaseAuth.instance.currentUser;
    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty) return display;
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading3.copyWith(color: textColor),
                    ),
                  ),
                  if (showGreeting) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Hello, ${_resolveUserName()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            actions,
          ],
        ),
      ),
    );
  }
}
