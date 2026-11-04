final class Session {
  const Session({required this.token, required this.expiresAtUnixSeconds});

  final String token;

  /// Unix time in SECONDS (same as `AuthResponse.expiresAtUnixSeconds`).
  final int expiresAtUnixSeconds;

  /// The clock is injected, so tests do not need real time.
  bool isExpired(DateTime now) =>
      now.millisecondsSinceEpoch ~/ 1000 >= expiresAtUnixSeconds;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.token == token &&
      other.expiresAtUnixSeconds == expiresAtUnixSeconds;

  @override
  int get hashCode => Object.hash(token, expiresAtUnixSeconds);

  /// Never print the token.
  @override
  String toString() => 'Session(token: hidden)';
}
