import 'package:flutter/material.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';

/// [RefreshIndicator] plus a full-area centered [CustomLogoLoader] while refresh runs.
///
/// The stock pull indicator is visually suppressed (transparent); the branded loader
/// appears in the middle of the screen during the refresh future.
class BrandedRefreshIndicator extends StatefulWidget {
  const BrandedRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40,
    this.overlayColor = const Color(0x59000000),
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Passed through to [RefreshIndicator.displacement].
  final double displacement;

  /// Scrim behind the loader (semi-transparent).
  final Color overlayColor;

  @override
  State<BrandedRefreshIndicator> createState() =>
      _BrandedRefreshIndicatorState();
}

class _BrandedRefreshIndicatorState extends State<BrandedRefreshIndicator> {
  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        RefreshIndicator(
          displacement: widget.displacement,
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          onRefresh: _handleRefresh,
          child: widget.child,
        ),
        if (_refreshing)
          Positioned.fill(
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: widget.overlayColor),
                child: const CustomLogoLoader(centerInViewport: true),
              ),
            ),
          ),
      ],
    );
  }
}
