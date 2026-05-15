import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/user_display_name_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class AppContentHeader extends StatefulWidget {
  const AppContentHeader({
    super.key,
    required this.title,
    required this.actions,
    this.showGreeting = false,
    this.textColor = Colors.white,
    this.backgroundColor,
  });

  /// Height of the title / actions row inside the header strip.
  static const double kHeaderHeight = 64;

  /// Breathing room below the title row, **painted with the same color** as the header
  /// so shells do not show a transparent band (often reads as white over the canvas).
  static const double kGapBelowHeader = AppSpacing.lg;

  /// Total height of the fixed header widget (row + gap). Shell top padding should match.
  static const double kTotalHeaderHeight = kHeaderHeight + kGapBelowHeader;

  final String title;
  final Widget actions;
  final bool showGreeting;
  final Color textColor;
  final Color? backgroundColor;

  @override
  State<AppContentHeader> createState() => _AppContentHeaderState();
}

class _AppContentHeaderState extends State<AppContentHeader> {
  late Future<String> _displayNameFuture;

  @override
  void initState() {
    super.initState();
    _displayNameFuture = UserDisplayNameService.resolveForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final Color headerBg = widget.backgroundColor ?? DashboardChrome.cardFill;

    return SizedBox(
      height: AppContentHeader.kTotalHeaderHeight,
      child: ColoredBox(
        color: headerBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AppContentHeader.kHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading3.copyWith(
                                color: widget.textColor,
                              ),
                            ),
                          ),
                          if (widget.showGreeting) ...[
                            const SizedBox(width: 12),
                            Flexible(
                              child: FutureBuilder<String>(
                                future: _displayNameFuture,
                                builder: (context, snapshot) {
                                  final name = (snapshot.data ?? '').trim();
                                  if (name.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    'Hello, $name',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: widget.textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    widget.actions,
                  ],
                ),
              ),
            ),
            SizedBox(
              height: AppContentHeader.kGapBelowHeader,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
