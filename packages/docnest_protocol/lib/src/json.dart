/// Strict JSON readers for DTO decoding.
///
/// Two rules, both deliberate:
///  * unknown keys are ignored, so a newer peer never breaks an older one;
///  * required fields with the wrong type throw [FormatException] rather than
///    silently defaulting, because a silent default can corrupt user data.
library;

Map<String, Object?> jsonObject(Object? value, {String context = 'value'}) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('$context must be a JSON object, got ${value.runtimeType}');
}

String jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Field "$key" must be a string, got ${value.runtimeType}');
}

String? jsonStringOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Field "$key" must be a string or null, got ${value.runtimeType}');
}

int jsonInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('Field "$key" must be an integer, got ${value.runtimeType}');
}

int? jsonIntOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return jsonInt(json, key);
}

bool jsonBool(Map<String, Object?> json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('Field "$key" must be a boolean, got ${value.runtimeType}');
}

double? jsonDoubleOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Field "$key" must be a number, got ${value.runtimeType}');
}

List<String> jsonStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const <String>[];
  if (value is! List) {
    throw FormatException('Field "$key" must be a list, got ${value.runtimeType}');
  }
  return value
      .map((item) {
        if (item is String) return item;
        throw FormatException('Field "$key" must contain strings, got ${item.runtimeType}');
      })
      .toList(growable: false);
}

List<int> jsonIntList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const <int>[];
  if (value is! List) {
    throw FormatException('Field "$key" must be a list, got ${value.runtimeType}');
  }
  return value
      .map((item) {
        if (item is int) return item;
        throw FormatException('Field "$key" must contain integers, got ${item.runtimeType}');
      })
      .toList(growable: false);
}

/// Reads an ISO-8601 timestamp and normalises it to UTC.
DateTime jsonDateTime(Map<String, Object?> json, String key) {
  final raw = jsonString(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('Field "$key" is not an ISO-8601 timestamp: $raw');
  return parsed.toUtc();
}

DateTime? jsonDateTimeOrNull(Map<String, Object?> json, String key) {
  final raw = jsonStringOrNull(json, key);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('Field "$key" is not an ISO-8601 timestamp: $raw');
  return parsed.toUtc();
}

/// Wire representation of a timestamp: UTC, millisecond precision.
String dateTimeToWire(DateTime value) => value.toUtc().toIso8601String();
