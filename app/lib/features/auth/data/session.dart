import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:meta/meta.dart';

@immutable
final class Session {
  const new({
    required this.token,
    required this.expiresAtUnixSeconds,
    this.user,
  });

  final String token;

  /// Unix time in SECONDS (same as `AuthResponse.expiresAtUnixSeconds`).
  final int expiresAtUnixSeconds;

  /// The user who owns this session. It lets the app start signed in when the
  /// server is not reachable. It is null for sessions saved by an older
  /// version of the app.
  final UserProfile? user;

  /// The clock is injected, so tests do not need real time.
  bool isExpired(DateTime now) =>
      now.millisecondsSinceEpoch ~/ 1000 >= expiresAtUnixSeconds;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.token == token &&
      other.expiresAtUnixSeconds == expiresAtUnixSeconds &&
      other.user == user;

  @override
  int get hashCode => Object.hash(token, expiresAtUnixSeconds, user);

  /// Never print the token.
  @override
  String toString() => 'Session(token: hidden)';
}
