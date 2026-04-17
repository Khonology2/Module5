import 'package:flutter/material.dart';

/// Figma-aligned surface for KPA excellence accordion rows and Goal Workspace
/// section cards: 5.32 radius, white @ 14% (dark) / frosted white (light), drop shadow.
abstract final class KpaExcellenceSurface {
  static const double borderRadius = 5.32;
  static const double shadowOffset = 3.55;

  static Color fill(bool light) => light
      ? const Color(0x99FFFFFF)
      : Colors.white.withValues(alpha: 0.14);

  static BoxDecoration cardDecoration(bool light) {
    final r = BorderRadius.circular(borderRadius);
    return BoxDecoration(
      color: fill(light),
      borderRadius: r,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          offset: const Offset(0, shadowOffset),
          blurRadius: shadowOffset,
          spreadRadius: 0,
        ),
      ],
    );
  }

  static BorderRadius get borderRadiusGeometry =>
      BorderRadius.circular(borderRadius);
}
