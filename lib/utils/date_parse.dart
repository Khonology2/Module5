/// Backend- and legacy timestamp map date parsing (no Firestore SDK).
DateTime? parseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
  }
  if (value is Map) {
    final sec = value['seconds'] ?? value['_seconds'];
    if (sec is int) {
      final nano = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
      final ms = sec * 1000 +
          (nano is int ? nano ~/ 1000000 : 0);
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }
  return DateTime.tryParse(value.toString());
}

DateTime parseDate(dynamic value, {DateTime? fallback}) {
  return parseNullableDate(value) ?? fallback ?? DateTime.now();
}
