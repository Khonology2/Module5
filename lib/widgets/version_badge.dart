import 'package:flutter/material.dart';
import 'package:pdh/version_info.dart';

/// Displays the current app version label.
class VersionBadge extends StatelessWidget {
  const VersionBadge({
    super.key,
    this.padding = const EdgeInsets.all(8),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Padding(
        padding: padding,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            appVersionLabel,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

