abstract final class AuthValidators {
  static const int emailMax = 255;
  static const int emailLocalMax = 64;
  static const int passwordMin = 8;
  static const int passwordMax = 128;
  static const int displayNameMax = 80;

  /// , ; < >  (O(1) lookup)
  static const Set<int> _forbiddenEmailChars = <int>{0x2C, 0x3B, 0x3C, 0x3E};

  /// Send this value to the server, not the raw input.
  static String normalizeEmail(String? value) =>
      (value ?? '').trim().toLowerCase();

  static String? email(String? value) {
    final text = normalizeEmail(value);
    if (text.isEmpty) return 'Email is required';
    if (text.length > emailMax || !_hasValidShape(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? signupPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < passwordMin) {
      return 'Use at least $passwordMin characters';
    }
    if (text.length > passwordMax) return 'Use at most $passwordMax characters';
    return null;
  }

  static String? signinPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length > passwordMax) return 'Use at most $passwordMax characters';
    return null;
  }

  static String? displayName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Name is required';
    if (text.length > displayNameMax) return 'Name is too long';
    if (text.codeUnits.any(_isControl)) return 'Name has invalid characters';
    return null;
  }

  static bool _hasValidShape(String text) {
    for (final unit in text.codeUnits) {
      // ASCII only, no space, no control characters.
      if (unit <= 0x20 || unit >= 0x7F) return false;
      if (_forbiddenEmailChars.contains(unit)) return false;
    }
    final at = text.indexOf('@');
    if (at <= 0 || at != text.lastIndexOf('@')) return false;
    final local = text.substring(0, at);
    final domain = text.substring(at + 1);
    if (local.length > emailLocalMax) return false;
    return domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.') &&
        !domain.contains('..');
  }

  static bool _isControl(int unit) =>
      unit <= 0x1F || (unit >= 0x7F && unit <= 0x9F);
}
