/// Strict readers. A wrong shape throws FormatException.
/// The message has only the key name, never the value (it may be a token).
extension JsonObjectReader on Map<String, Object?> {
  String requireString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected a string at "$key"');
  }

  int requireInt(String key) {
    final value = this[key];
    if (value is int) return value;
    throw FormatException('Expected an integer at "$key"');
  }

  Map<String, Object?> requireObject(String key) {
    final value = this[key];
    if (value is Map<String, Object?>) return value;
    throw FormatException('Expected an object at "$key"');
  }

  /// Any JSON number (`5` and `5.5` both work).
  num requireNum(String key) {
    final value = this[key];
    if (value is num) return value;
    throw FormatException('Expected a number at "$key"');
  }

  /// Missing key or `null` gives null. A wrong type throws.
  String? optionalString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Expected a string or null at "$key"');
  }

  /// Missing key or `null` gives null. A wrong type throws.
  int? optionalInt(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    throw FormatException('Expected an integer or null at "$key"');
  }

  /// Missing key or `null` gives null. A wrong type throws.
  num? optionalNum(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value;
    throw FormatException('Expected a number or null at "$key"');
  }

  /// A list of JSON objects. Any other element type throws.
  List<Map<String, Object?>> requireObjectList(String key) {
    final value = this[key];
    if (value is! List<Object?>) {
      throw FormatException('Expected a list at "$key"');
    }
    final result = <Map<String, Object?>>[];
    for (final item in value) {
      if (item is! Map<String, Object?>) {
        throw FormatException('Expected objects in the list at "$key"');
      }
      result.add(item);
    }
    return List<Map<String, Object?>>.unmodifiable(result);
  }
}
