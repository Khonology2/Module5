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

  /// Height of the opaque title / actions strip (background image shows below).
  static const double kHeaderHeight = 64;

  /// Transparent breathing room between the header strip and page content.
  static const double kContentInsetBelowHeader = AppSpacing.xl;

  /// Opaque header strip height (for fixed/positioned header sizing).
  static const double kTotalHeaderHeight = kHeaderHeight;

  /// Top padding for shell content so it clears the header + transparent gap.
  static const double kShellContentTopOffset =
      kHeaderHeight + kContentInsetBelowHeader;

  /// Page insets when the body sits inside a full-bleed background (e.g. [MainLayout]).
  static EdgeInsets shellBodyPadding({
    double horizontal = AppSpacing.xxl,
    double bottom = AppSpacing.xxl,
  }) =>
      EdgeInsets.fromLTRB(
        horizontal,
        kShellContentTopOffset,
        horizontal,
        bottom,
      );

  /// [AppSpacing.screenPadding] with shell top inset (background must be full-bleed).
  static EdgeInsets shellScrollPadding([
    EdgeInsets base = AppSpacing.screenPadding,
  ]) =>
      base.copyWith(top: kShellContentTopOffset);

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
                        style: AppTypography.heading3.copyWith(
                          color: textColor,
                        ),
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
