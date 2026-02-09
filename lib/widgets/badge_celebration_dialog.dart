import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_typography.dart';

class BadgeCelebrationDialog extends StatelessWidget {
  final String title;
  final String badgeName;
  final String badgeDescription;
  final Color accentColor;
  final Widget badgeIcon;
  final int moreCount;

  const BadgeCelebrationDialog({
    super.key,
    required this.title,
    required this.badgeName,
    required this.badgeDescription,
    required this.accentColor,
    required this.badgeIcon,
    this.moreCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: _DialogBody(
          title: title,
          badgeName: badgeName,
          badgeDescription: badgeDescription,
          accentColor: accentColor,
          badgeIcon: badgeIcon,
          moreCount: moreCount,
        ),
      ),
    );
  }
}

class _DialogBody extends StatelessWidget {
  final String title;
  final String badgeName;
  final String badgeDescription;
  final Color accentColor;
  final Widget badgeIcon;
  final int moreCount;

  const _DialogBody({
    required this.title,
    required this.badgeName,
    required this.badgeDescription,
    required this.accentColor,
    required this.badgeIcon,
    required this.moreCount,
  });

  @override
  Widget build(BuildContext context) {
    final bg1 = accentColor;
    final bg2 = accentColor.withValues(alpha: 0.65);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Center(
                    child: IconTheme(
                      data: const IconThemeData(color: Colors.white, size: 72),
                      child: badgeIcon,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTypography.heading2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  badgeName,
                  style: AppTypography.heading4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  badgeDescription,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (moreCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '+ $moreCount more badge${moreCount == 1 ? '' : 's'} earned',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _SparkleLayer())),
        ],
      ),
    );
  }
}

class _SparkleLayer extends StatefulWidget {
  const _SparkleLayer();

  @override
  State<_SparkleLayer> createState() => _SparkleLayerState();
}

class _SparkleLayerState extends State<_SparkleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

    // Deterministic-ish sparkles (so rebuilds don't reshuffle wildly)
    final rng = math.Random(1337);
    _sparkles = List.generate(18, (i) {
      return _Sparkle(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        size: 10 + rng.nextDouble() * 14,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        return CustomPaint(
          painter: _SparklePainter(
            t: _t.value,
            sparkles: _sparkles,
          ),
        );
      },
    );
  }
}

class _Sparkle {
  final double dx; // 0..1
  final double dy; // 0..1
  final double size;
  final double phase;

  const _Sparkle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
}

class _SparklePainter extends CustomPainter {
  final double t;
  final List<_Sparkle> sparkles;

  const _SparklePainter({required this.t, required this.sparkles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparkles) {
      // A little "breathing" twinkle
      final twinkle = (0.35 + 0.65 * (0.5 + 0.5 * math.sin((t * 2 * math.pi) + s.phase)));
      final alpha = (0.08 + 0.18 * twinkle).clamp(0.0, 0.35);
      paint.color = Colors.white.withValues(alpha: alpha);

      final x = s.dx * size.width;
      final y = s.dy * size.height;
      final r = s.size * (0.55 + 0.45 * twinkle);

      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.sparkles != sparkles;
  }
}

