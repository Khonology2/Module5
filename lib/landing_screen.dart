// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:math' as math; // For math functions

// Typewriter effect widget
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final TextAlign textAlign;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 50),
    this.textAlign = TextAlign.left,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _displayText = '';
    _currentIndex = 0;
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}

// Custom painter for rotating gradient overlay
class RotatingGradientPainter extends CustomPainter {
  final double rotation;

  RotatingGradientPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Create rotating gradient
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: rotation,
      endAngle: rotation + math.pi / 2,
      colors: [
        Colors.transparent,
        const Color(0xFFC10D00).withOpacity(0.15),
        Colors.transparent,
        const Color(0xFFC10D00).withOpacity(0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(RotatingGradientPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

// The main screen widget for the Personal Development Hub.
class PersonalDevelopmentHubScreen extends StatefulWidget {
  const PersonalDevelopmentHubScreen({super.key});

  @override
  State<PersonalDevelopmentHubScreen> createState() => _PersonalDevelopmentHubScreenState();
}

class _PersonalDevelopmentHubScreenState extends State<PersonalDevelopmentHubScreen> with TickerProviderStateMixin {
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoSlideAnimation;
  late Animation<double> _logoFadeAnimation;
  
  // Background animation controllers
  late AnimationController _kenBurnsController;
  late AnimationController _gradientController;
  late AnimationController _parallaxController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  
  // Background animations
  late Animation<double> _kenBurnsScale;
  late Animation<Offset> _kenBurnsOffset;
  late Animation<double> _gradientRotation;
  late Animation<double> _parallaxOffset;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    inspirationalLines = [
      "Cultivate your mind, blossom your potential.",
      "Every step forward is a victory.",
      "Organize your life, clarify your purpose.",
      "Knowledge is the compass of growth.",
      "Build strong habits, build a strong future.",
      "Financial wisdom empowers freedom.",
      "Unlock your inner creativity.",
      "Mindfulness lights the path to peace.",
      "Fitness fuels your ambition.",
      "Learn relentlessly, live boundlessly.",
      "Your journey, your rules, your growth.",
      "Small changes, significant impact.",
      "Embrace the challenge, find your strength.",
      "Beyond limits, lies growth.",
      "Master your days, master your destiny.",
      "Innovate, iterate, inspire.",
      "The best investment is in yourself.",
      "Find your balance, elevate your being.",
      "Progress, not perfection.",
      "Dream big, start small, act now.",
    ];
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentLineIndex = (_currentLineIndex + 1) % inspirationalLines.length;
      });
    });

    // Initialize logo animation controller
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create slide animation (from -100 to 0)
    _logoSlideAnimation = Tween<double>(
      begin: -100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Create fade animation (from 0 to 1)
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeIn,
    ));

    // Start logo animation
    _logoAnimationController.forward();

    // Initialize Ken Burns Effect (slow zoom and pan) - Reduced movement to prevent white edges
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    );
    // Reduced scale from 1.15 to 1.05 for subtler zoom
    _kenBurnsScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
    // Reduced offset movement significantly to prevent white edges
    _kenBurnsOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0.015, 0.01)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0.015, 0.01), end: const Offset(-0.01, 0.015)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(-0.01, 0.015), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut));
    _kenBurnsController.repeat(reverse: true);

    // Initialize Animated Gradient Overlay (rotating gradient)
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _gradientRotation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );
    _gradientController.repeat();

    // Initialize Parallax Floating Effect
    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _parallaxOffset = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _parallaxController, curve: Curves.easeInOut),
    );
    _parallaxController.repeat(reverse: true);

    // Initialize Pulsing Glow Effect
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    // Initialize Particle Animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _particleController.repeat();

    // Precache hero images after first frame to avoid jank on first paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted) return;
      // Background image sized to screen width to reduce decode cost
      final int bgWidth = (MediaQuery.of(context).size.width * 1.5).toInt();
      precacheImage(
        const AssetImage('assets/khono_bg.png'),
        context,
        size: Size(bgWidth.toDouble(), MediaQuery.of(context).size.height),
      );
      // Logo: decode at device-pixel-ratio size to keep it crisp
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      precacheImage(
        const AssetImage('assets/khono.png'),
        context,
        size: Size(320 * dpr, 160 * dpr),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _logoAnimationController.dispose();
    _kenBurnsController.dispose();
    _gradientController.dispose();
    _parallaxController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background with 5 Modern Effects
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _kenBurnsController,
                _gradientController,
                _parallaxController,
                _glowController,
                _particleController,
              ]),
              builder: (context, child) {
                return Stack(
                  children: [
                    // Dark background to prevent white edges
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                      ),
                    ),
                    // 1. Ken Burns Effect - Slow zoom and pan (clipped to prevent white edges)
                    Positioned.fill(
                      child: ClipRect(
                        child: Transform.scale(
                          scale: _kenBurnsScale.value,
                          alignment: Alignment.center,
                          child: Transform.translate(
                            offset: Offset(
                              _kenBurnsOffset.value.dx * screenSize.width,
                              _kenBurnsOffset.value.dy * screenSize.height,
                            ),
                            child: Image.asset(
                              'assets/khono_bg.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              cacheWidth: (screenSize.width * 1.5).toInt(),
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // 2. Animated Gradient Overlay - Rotating gradient
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RotatingGradientPainter(
                          rotation: _gradientRotation.value,
                        ),
                      ),
                    ),
                    
                    // 3. Parallax Floating Effect
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          math.sin(_parallaxController.value * 2 * math.pi) * _parallaxOffset.value,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // 4. Pulsing Glow Effect
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [
                              const Color(0xFFC10D00).withOpacity(_glowOpacity.value * 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // 5. Particle Effects - Floating particles
                    ...List.generate(20, (index) {
                      final progress = (_particleController.value + (index / 20)) % 1.0;
                      final x = (index * 37.5) % screenSize.width;
                      final y = screenSize.height * (1 - progress);
                      final opacity = math.sin(progress * math.pi);
                      final size = 2.0 + (math.sin(progress * 2 * math.pi) * 1.5);
                      
                      return Positioned(
                        left: x,
                        top: y,
                        child: Opacity(
                          opacity: opacity * 0.6,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    // Dark overlay on top
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4),
                          BlendMode.darken,
                        ),
                        child: Container(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Content overlay
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo - Centered with slide-in animation
                  AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _logoSlideAnimation.value),
                        child: Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: Image.asset(
                            'assets/khono.png',
                            height: 160,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Tagline - Centered with typewriter effect
                  Center(
                    child: TypewriterText(
                      text: 'Your Growth Journey, Simplified',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC10D00),
                        fontFamily: 'Poppins',
                      ),
                      speed: const Duration(milliseconds: 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Inspirational message - Centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        inspirationalLines[_currentLineIndex],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withAlpha(204),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Button - Centered
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/sign_in');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC10D00), // Use the new red color
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: const StadiumBorder(), // Changed to StadiumBorder
                      ),
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}