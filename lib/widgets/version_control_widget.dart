import 'package:flutter/material.dart';

/// A version control widget that displays the app version with hover animation.
/// Displays version information at the bottom of screens with smooth hover effects.
class VersionControlWidget extends StatefulWidget {
  const VersionControlWidget({
    super.key,
    this.version = 'Ver. 2026.02.DD1_SIT',
    this.fontSize = 12.0,
    this.textColor = Colors.white70,
    this.hoverColor = Colors.white,
  });

  final String version;
  final double fontSize;
  final Color textColor;
  final Color hoverColor;

  @override
  State<VersionControlWidget> createState() => _VersionControlWidgetState();
}

class _VersionControlWidgetState extends State<VersionControlWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: widget.textColor,
      end: widget.hoverColor,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    if (isHovering) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Text(
              widget.version,
              style: TextStyle(
                fontSize: widget.fontSize,
                color: _colorAnimation.value,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
