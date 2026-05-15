import 'package:flutter/material.dart';

/// Branded three-disc loader: discs rotate CW / CCW / CW with slightly varied speeds.
///
/// Use this instead of the default Material circular progress widget for async UI; PNGs stay transparent.
class CustomLogoLoader extends StatefulWidget {
  /// Default disc cell size (buttons, rows, compact loaders).
  static const double kDefaultDiscSize = 40;

  /// Larger logo when [centerInViewport] is true and [size] is left at default — full content-area spinners only.
  static const double kContentAreaDiscSize = 56;

  const CustomLogoLoader({
    super.key,
    this.size = kDefaultDiscSize,
    this.discOverlap,
    this.clockwiseDuration = const Duration(milliseconds: 2400),
    this.counterClockwiseDuration = const Duration(milliseconds: 2680),
    this.clockwiseOuterDuration = const Duration(milliseconds: 2520),
    this.centerInViewport = false,
  });

  /// When true, fills available height in route/content areas and centers the loader (sidebar pages).
  final bool centerInViewport;

  /// Edge length of each disc's square layout cell (before overlap).
  /// When [centerInViewport] is true and this equals [kDefaultDiscSize], the
  /// widget uses [kContentAreaDiscSize] instead (full-screen/content loaders only).
  final double size;

  /// Horizontal overlap between consecutive discs (pulls arcs together). Defaults to ~24% of [size].
  final double? discOverlap;

  /// Left disc (clockwise).
  final Duration clockwiseDuration;

  /// Middle disc (counter-clockwise).
  final Duration counterClockwiseDuration;

  /// Right disc (clockwise).
  final Duration clockwiseOuterDuration;

  @override
  State<CustomLogoLoader> createState() => _CustomLogoLoaderState();
}

/// Compact loader for buttons and tight layouts (const-safe).
class CustomLogoLoaderInline extends StatelessWidget {
  const CustomLogoLoaderInline({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 44,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: CustomLogoLoader(
          size: 22,
          discOverlap: 8,
          centerInViewport: false,
        ), // explicit small size — not affected by content-area scaling
      ),
    );
  }
}

class _CustomLogoLoaderState extends State<CustomLogoLoader>
    with TickerProviderStateMixin {
  late final AnimationController _cw1;
  late final AnimationController _ccw;
  late final AnimationController _cw2;

  late final Animation<double> _turns1;
  late final Animation<double> _turns2;
  late final Animation<double> _turns3;

  @override
  void initState() {
    super.initState();
    _cw1 = AnimationController(vsync: this, duration: widget.clockwiseDuration)
      ..repeat();
    _ccw = AnimationController(
      vsync: this,
      duration: widget.counterClockwiseDuration,
    )..repeat();
    _cw2 = AnimationController(
      vsync: this,
      duration: widget.clockwiseOuterDuration,
    )..repeat();

    _turns1 = Tween<double>(begin: 0, end: 1).animate(_cw1);
    _turns2 = Tween<double>(begin: 0, end: -1).animate(_ccw);
    _turns3 = Tween<double>(begin: 0, end: 1).animate(_cw2);
  }

  @override
  void dispose() {
    _cw1.dispose();
    _ccw.dispose();
    _cw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = widget.centerInViewport &&
            widget.size == CustomLogoLoader.kDefaultDiscSize
        ? CustomLogoLoader.kContentAreaDiscSize
        : widget.size;
    final overlap = widget.discOverlap ?? (disc * 0.24);
    final rowWidth = 3 * disc - 2 * overlap;

    final loader = SizedBox(
      width: rowWidth,
      height: disc,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: RotationTransition(
              turns: _turns1,
              child: _DiscImage(asset: 'assets/disc_1.png', size: disc),
            ),
          ),
          Positioned(
            left: disc - overlap,
            top: 0,
            child: RotationTransition(
              turns: _turns2,
              child: _DiscImage(asset: 'assets/disc_2.png', size: disc),
            ),
          ),
          Positioned(
            left: 2 * (disc - overlap),
            top: 0,
            child: RotationTransition(
              turns: _turns3,
              child: _DiscImage(asset: 'assets/disc_3.png', size: disc),
            ),
          ),
        ],
      ),
    );

    final scaled = LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (maxW.isFinite &&
            maxW < rowWidth &&
            maxH.isFinite &&
            maxH < double.infinity) {
          return FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: loader,
          );
        }
        return loader;
      },
    );

    final core = Semantics(label: 'Loading', child: scaled);

    if (!widget.centerInViewport) {
      return core;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final minH = h.isFinite && h > 0 ? h : 400.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(child: core),
          ),
        );
      },
    );
  }
}

class _DiscImage extends StatelessWidget {
  const _DiscImage({required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            SizedBox(width: size, height: size),
      ),
    );
  }
}
