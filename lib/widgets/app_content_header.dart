import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class AppContentHeader extends StatelessWidget {
  const AppContentHeader({
    super.key,
    required this.title,
    required this.actions,
    this.showGreeting = false,
    this.textColor = Colors.white,
    this.backgroundColor,
  });

  static const double kHeaderHeight = 64;

  /// Space between the fixed header strip and the scrollable page body.
  /// Shells combine this with [kHeaderHeight] for content insets (not scroll padding).
  static const double kGapBelowHeader = AppSpacing.lg;

  final String title;
  final Widget actions;
  final bool showGreeting;
  final Color textColor;
  final Color? backgroundColor;

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
    final Color headerBg = backgroundColor ?? DashboardChrome.cardFill;

    return SizedBox(
      height: kHeaderHeight,
      child: ColoredBox(
        color: headerBg,
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
      ),
    );
  }
}
