import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_components.dart';

/// Toggles Employee Dashboard light mode (white cards, black text, light background image).
final ValueNotifier<bool> employeeDashboardLightModeNotifier = ValueNotifier<bool>(false);

class EmployeeDashboardThemeScope extends InheritedWidget {
  const EmployeeDashboardThemeScope({
    super.key,
    required this.light,
    required super.child,
  });

  final bool light;

  static EmployeeDashboardThemeScope? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EmployeeDashboardThemeScope>();
  }

  static bool lightOf(BuildContext context) => _maybeOf(context)?.light ?? false;

  @override
  bool updateShouldNotify(EmployeeDashboardThemeScope oldWidget) =>
      light != oldWidget.light;
}

/// Shared palette for “solid surface” light/dark UI.
///
/// Dark mode: solid #3D3F40 surfaces with solid white text.
/// Light mode: solid white surfaces with solid black text.
class DashboardChrome {
  DashboardChrome._();

  static const Color darkSurface = Color(0xFF3D3F40);

  static bool get light => employeeDashboardLightModeNotifier.value;

  static Color get cardFill => light ? const Color(0xFFFFFFFF) : darkSurface;

  static Color get border => light
      ? const Color(0x33000000)
      : Colors.white.withValues(alpha: 0.2);

  static Color get fg => light ? const Color(0xFF000000) : Colors.white;

  static List<Color>? get lightGradient => light
      ? [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.08),
        ]
      : null;
}

/// Convenience wrapper that:\n
/// - listens to [employeeDashboardLightModeNotifier]\n
/// - provides [EmployeeDashboardThemeScope]\n
/// - paints the shared background image (unless [embedded] is true)\n
class DashboardThemedBackground extends StatelessWidget {
  const DashboardThemedBackground({
    super.key,
    required this.child,
    this.embedded = false,
  });

  final Widget child;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, light, _) {
        final Widget scoped = EmployeeDashboardThemeScope(
          light: light,
          child: child,
        );

        if (embedded) return scoped;

        return AppComponents.backgroundWithImage(
          blurSigma: 0,
          imagePath: light ? 'assets/light_mode_bg.png' : 'assets/khono_bg.png',
          gradientColors: DashboardChrome.lightGradient,
          child: scoped,
        );
      },
    );
  }
}
