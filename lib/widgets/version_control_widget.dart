// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdh/services/commit_service.dart';

/// A version control widget that displays the app version with hover animation.
/// Displays version information at the bottom of screens with smooth hover effects.
class VersionControlWidget extends StatefulWidget {
  const VersionControlWidget({
    super.key,
    this.version = 'Ver. 2026.02.CD1_SIT',
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  /// Commit data loaded from bundled JSON
  CommitData? _commitData;

  /// Loading state
  bool _isLoading = true;

  /// Timer for periodic data refresh (every 2 minutes)
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _colorAnimation =
        ColorTween(begin: widget.textColor, end: widget.hoverColor).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    // Load commit data on initialization
    _loadCommitData();

    // Setup auto-refresh mechanisms
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Load commit data from the bundled JSON file
  Future<void> _loadCommitData() async {
    try {
      final commitData = await CommitService.loadCommitData();
      if (mounted) {
        setState(() {
          _commitData = commitData;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Use fallback data if loading fails
      if (mounted) {
        setState(() {
          _commitData = CommitService.getFallbackCommitData();
          _isLoading = false;
        });
      }
    }
  }

  /// Setup auto-refresh mechanisms
  void _setupAutoRefresh() {
    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Setup periodic refresh every 2 minutes
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _refreshCommitData(),
    );
  }

  /// Refresh commit data from service
  Future<void> _refreshCommitData() async {
    try {
      final commitData = await CommitService.loadCommitData();
      if (mounted) {
        setState(() {
          _commitData = commitData;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Keep existing data if refresh fails
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    // Generate tooltip message based on loaded commit data
    String tooltipMessage;
    if (_isLoading) {
      tooltipMessage = 'Loading commit data...';
    } else if (_commitData != null) {
      tooltipMessage = _commitData!.getTooltipMessage();
    } else {
      tooltipMessage = 'Commit data unavailable';
    }

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Tooltip(
        message: tooltipMessage,
        textAlign: TextAlign.center,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Inter',
          height: 1.4,
        ),
        showDuration: const Duration(seconds: 10),
        waitDuration: const Duration(milliseconds: 500),
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
      ),
    );
  }
}
