import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:math' show Random;

class FloatingCirclesParticleAnimation extends StatefulWidget {
  final Color circleColor;
  final int numberOfParticles;
  final double maxParticleSize;
  final double minParticleSize;
  final Duration animationDuration;
  final double maxDistance;

  const FloatingCirclesParticleAnimation({
    super.key,
    this.circleColor = Colors.white,
    this.numberOfParticles = 20,
    this.maxParticleSize = 8.0,
    this.minParticleSize = 2.0,
    this.animationDuration = const Duration(seconds: 4),
    this.maxDistance = 100.0,
  });

  @override
  FloatingCirclesParticleAnimationState createState() =>
      FloatingCirclesParticleAnimationState();
}

class FloatingCirclesParticleAnimationState
    extends State<FloatingCirclesParticleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  final List<Offset> _targetPositions = [];
  final List<Offset> _originalPositions = [];
  final List<double> _particleSizes = [];
  final List<double> _opacities = [];
  bool _isExploding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(reverse: true);

    // Initialize particles
    for (int i = 0; i < widget.numberOfParticles; i++) {
      _particles.add(Particle(
        position: Offset.zero,
        velocity: Offset.zero,
        radius: 0,
        color: widget.circleColor,
      ));
      _targetPositions.add(Offset.zero);
      _originalPositions.add(Offset.zero);
      _particleSizes.add(0);
      _opacities.add(0);
    }

    // Start with particles in the center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetParticles();
      }
    });
  }

  void _resetParticles() {
    if (!mounted) return;
    
    final size = context.size;
    if (size == null || size.isEmpty) return;

    for (int i = 0; i < widget.numberOfParticles; i++) {
      _originalPositions[i] = Offset(
        size.width / 2,
        size.height / 2,
      );
      _targetPositions[i] = _getRandomPosition(size);
      _particleSizes[i] = widget.minParticleSize +
          _random.nextDouble() * (widget.maxParticleSize - widget.minParticleSize);
      _opacities[i] = 0.2 + _random.nextDouble() * 0.8;
      
      _particles[i] = Particle(
        position: _originalPositions[i],
        velocity: _getRandomVelocity(),
        radius: _particleSizes[i],
        color: widget.circleColor.withValues(alpha: _opacities[i]),
      );
    }

    if (!_isExploding) {
      _startAnimation();
    }
  }

  Offset _getRandomPosition(Size size) {
    return Offset(
      _random.nextDouble() * size.width,
      _random.nextDouble() * size.height,
    );
  }

  Offset _getRandomVelocity() {
    final speed = 0.5 + _random.nextDouble() * 1.5;
    final angle = _random.nextDouble() * 2 * math.pi;
    return Offset(math.cos(angle) * speed, math.sin(angle) * speed);
  }

  void _startAnimation() {
    _controller.forward(from: 0);
  }

  void triggerParticleExplosion() {
    if (!mounted) return;
    
    final size = context.size;
    if (size == null || size.isEmpty) return;

    setState(() {
      _isExploding = true;
      
      // Set new random target positions for explosion
      for (int i = 0; i < widget.numberOfParticles; i++) {
        _targetPositions[i] = _getRandomPosition(size);
      }
    });

    // After explosion, return to floating animation
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isExploding = false;
          _resetParticles();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateParticles();
        return CustomPaint(
          painter: ParticlePainter(particles: _particles),
          size: Size.infinite,
        );
      },
    );
  }

  void _updateParticles() {
    if (!mounted) return;
    
    final size = context.size;
    if (size == null || size.isEmpty) return;

    for (int i = 0; i < widget.numberOfParticles; i++) {
      final progress = _controller.value;
      final currentTarget = _isExploding ? _targetPositions[i] : _originalPositions[i];
      
      // Smooth movement between positions
      final dx = currentTarget.dx - _particles[i].position.dx;
      final dy = currentTarget.dy - _particles[i].position.dy;
      
      _particles[i] = _particles[i].copyWith(
        position: Offset(
          _particles[i].position.dx + dx * 0.1,
          _particles[i].position.dy + dy * 0.1,
        ),
        radius: _particleSizes[i] * (0.8 + 0.4 * math.sin(progress * 2 * math.pi)),
        color: widget.circleColor.withValues(
          alpha: _opacities[i] * (0.7 + 0.3 * math.sin(progress * 2 * math.pi + i)),
        ),
      );
      
      // Random movement when not exploding
      if (!_isExploding) {
        _particles[i] = _particles[i].copyWith(
          position: Offset(
            _particles[i].position.dx + _particles[i].velocity.dx,
            _particles[i].position.dy + _particles[i].velocity.dy,
          ),
        );
        
        // Bounce off edges
        if (_particles[i].position.dx < 0 || _particles[i].position.dx > size.width) {
          _particles[i] = _particles[i].copyWith(
            velocity: Offset(-_particles[i].velocity.dx, _particles[i].velocity.dy),
          );
        }
        if (_particles[i].position.dy < 0 || _particles[i].position.dy > size.height) {
          _particles[i] = _particles[i].copyWith(
            velocity: Offset(_particles[i].velocity.dx, -_particles[i].velocity.dy),
          );
        }
      }
    }
  }
}

class Particle {
  final Offset position;
  final Offset velocity;
  final double radius;
  final Color color;

  Particle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
  });

  Particle copyWith({
    Offset? position,
    Offset? velocity,
    double? radius,
    Color? color,
  }) {
    return Particle(
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      radius: radius ?? this.radius,
      color: color ?? this.color,
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        particle.position,
        particle.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
