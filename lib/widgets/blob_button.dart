import 'package:flutter/material.dart';

class BlobButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool isOutlined;
  final String? text;
  final IconData? icon;
  final double? fontSize;
  final FontWeight? fontWeight;

  const BlobButton({
    super.key,
    required this.onPressed,
    this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.padding,
    this.width,
    this.height,
    this.isOutlined = false,
    this.text,
    this.icon,
    this.fontSize,
    this.fontWeight,
  });

  @override
  State<BlobButton> createState() => _BlobButtonState();
}

class _BlobButtonState extends State<BlobButton>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  final Color _blobColor = const Color(0xFFC10D00);
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.ease,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    
    if (!isDisabled && _isHovered && _shimmerController.status != AnimationStatus.forward) {
      _shimmerController.forward();
    } else if (!_isHovered && _shimmerController.status != AnimationStatus.reverse && _shimmerController.value > 0) {
      _shimmerController.reverse();
    }

    final effectiveBlobColor = widget.borderColor ?? widget.backgroundColor ?? _blobColor;
    final effectiveTextColor = _isHovered && !isDisabled
        ? _textColor
        : (widget.foregroundColor ??
            (widget.isOutlined ? effectiveBlobColor : effectiveBlobColor));
    final effectiveBorderColor = widget.borderColor ?? widget.backgroundColor ?? _blobColor;
    final effectiveBackgroundColor = widget.backgroundColor;

    return MouseRegion(
      onEnter: isDisabled ? null : (_) => setState(() => _isHovered = true),
      onExit: isDisabled ? null : (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isDisabled ? null : _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _shimmerController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseController.isAnimating ? _pulseAnimation.value : 1.0,
              child: Opacity(
                opacity: isDisabled ? 0.5 : 1.0,
                child: Container(
                  width: widget.width,
                  height: widget.height ?? 56,
                  padding: widget.padding ??
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: 2,
                    ),
                    color: effectiveBackgroundColor ?? Colors.transparent,
                  ),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Shimmer/shine animation overlay
                      if (_isHovered && !isDisabled)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: CustomPaint(
                              painter: _ShimmerPainter(
                                progress: _shimmerAnimation.value,
                              ),
                            ),
                          ),
                        ),
                      // Content
                      Center(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: effectiveTextColor,
                            fontSize: widget.fontSize ?? (widget.text != null ? 18 : 16),
                            fontWeight: widget.fontWeight ?? FontWeight.w700,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                          child: widget.child ??
                              (widget.icon != null && widget.text != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(widget.icon, size: 18, color: effectiveTextColor),
                                        const SizedBox(width: 8),
                                        Text(widget.text!),
                                      ],
                                    )
                                  : widget.text != null
                                      ? Text(widget.text!)
                                      : widget.icon != null
                                          ? Icon(widget.icon, size: 18, color: effectiveTextColor)
                                          : const SizedBox()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a diagonal shimmer that sweeps from top-left to bottom-right
    // Similar to CSS: top: -100%, left: -100% -> top: 100%, left: 100%
    
    // Create a diagonal band for the shimmer effect
    final shimmerWidth = size.width * 0.8;
    
    // Draw a rotated rectangle to create the diagonal shimmer
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.785398); // 45 degrees in radians (π/4)
    canvas.translate(-size.width / 2, -size.height / 2);
    
    // Calculate the band position along the diagonal
    // Start from -100% (top-left outside) and move to 100% (bottom-right outside)
    final bandY = -size.height + (size.height * 3 * progress);
    
    // Draw the shimmer band with gradient
    final bandRect = Rect.fromLTWH(
      -size.width / 2,
      bandY - shimmerWidth / 2,
      size.width * 2,
      shimmerWidth,
    );
    
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.5, 1.0],
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(bandRect);
    
    canvas.drawRect(bandRect, bandPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
