/// Strict readers. A wrong shape throws FormatException.
/// The message has only the key name, never the value (it may be a token).
extension JsonObjectReader on Map<String, Object?> {
  String requireString(String key) {
    final Object? value = this[key];
    if (value is String) return value;
    throw FormatException('Expected a string at "$key"');
  }

  int requireInt(String key) {
    final Object? value = this[key];
    if (value is int) return value;
    throw FormatException('Expected an integer at "$key"');
  }

  Map<String, Object?> requireObject(String key) {
    final Object? value = this[key];
    if (value is Map<String, Object?>) return value;
    throw FormatException('Expected an object at "$key"');
  }
}
