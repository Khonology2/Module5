import 'package:flutter/material.dart';

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
