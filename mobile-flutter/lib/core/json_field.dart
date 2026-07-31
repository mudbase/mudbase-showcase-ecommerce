import 'dart:convert';

/// Mudbase Collection fields have a fixed type enum (string, number, boolean,
/// date, email, url, enum, reference) with no native array/object type.
/// Anything shaped like a list or a nested record (order line items, a
/// shipping address, extra product images) is stored as a JSON string in a
/// `string` field and parsed at the edges - a real, documented constraint of
/// the platform's Collections feature (see the web app's
/// `src/lib/json-field.ts` and its README "Known limitations"), not a
/// workaround specific to this app.
List<Map<String, dynamic>> parseJsonObjectList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
  } on FormatException {
    return const [];
  }
}

List<String> parseJsonStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList(growable: false);
  } on FormatException {
    return const [];
  }
}

Map<String, dynamic>? parseJsonObject(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String stringifyJsonField(Object? value) => jsonEncode(value);
