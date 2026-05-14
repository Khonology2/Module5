/// Normalizes [RouteSettings.arguments] so `Map<String, String>` and other [Map]
/// shapes from [Navigator] do not fail `is Map<String, dynamic>` checks.
Map<String, dynamic> routeArgumentsAsMap(Object? arguments) {
  if (arguments == null) return {};
  if (arguments is Map) {
    return Map<String, dynamic>.from(
      arguments.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return {};
}
