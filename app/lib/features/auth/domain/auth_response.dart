import 'package:apply_track/core/api/json_fields.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';

final class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.expiresAtUnixSeconds,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, Object?> json) {
    final String token = json.requireString('token');
    if (token.isEmpty) throw const FormatException('Empty "token"');
    return AuthResponse(
      token: token,
      expiresAtUnixSeconds: json.requireInt('expiresAtUnixSeconds'),
      user: UserProfile.fromJson(json.requireObject('user')),
    );
  }

  final String token;

  /// Unix time in SECONDS (all other API times are milliseconds).
  final int expiresAtUnixSeconds;
  final UserProfile user;

  /// Never print the token.
  @override
  String toString() => 'AuthResponse(token: hidden)';
}
