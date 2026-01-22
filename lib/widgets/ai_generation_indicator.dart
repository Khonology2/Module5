import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

class AIGenerationIndicator extends StatefulWidget {
  final String currentPhase;
  final ValueChanged<String> onPhaseChange;

  const AIGenerationIndicator({
    super.key,
    required this.currentPhase,
    required this.onPhaseChange,
  });

  @override
  State<AIGenerationIndicator> createState() => _AIGenerationIndicatorState();
}

class _AIGenerationIndicatorState extends State<AIGenerationIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ), // Slower rotation (600ms per rotation) so user can see it
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AIGenerationIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPhase != widget.currentPhase) {
      if (widget.currentPhase != 'Complete!') {
        _rotateBeforePhaseChange();
      }
    }
    if (widget.currentPhase == 'Complete!') {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fadeController.forward();
          _scaleController.forward();
        }
      });
    }
  }

  Future<void> _rotateBeforePhaseChange() async {
    // Rotate 2 times (2 full rotations = 4π)
    _rotationController.reset();
    await _rotationController.forward();
    _rotationController.reset();
    await _rotationController.forward();
    _rotationController.reset();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _rotationAnimation,
            _fadeAnimation,
            _scaleAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: widget.currentPhase == 'Complete!'
                  ? _scaleAnimation.value
                  : 1.0,
              child: Opacity(
                opacity: widget.currentPhase == 'Complete!'
                    ? _fadeAnimation.value
                    : 1.0,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/videos/Ai_Avatar.gif',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          widget.currentPhase,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
