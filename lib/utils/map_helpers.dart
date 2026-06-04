/// Normalize loosely-typed JSON maps from backend responses.
Map<String, dynamic> asStringKeyedMap(dynamic value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((Object? key, Object? val) {
      out[key.toString()] = val;
    });
    return out;
  }
  return <String, dynamic>{};
}
