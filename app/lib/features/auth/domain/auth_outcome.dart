import 'package:apply_track/features/auth/domain/user_profile.dart';

enum AuthFailureKind {
  validation,
  emailTaken,
  invalidCredentials,
  rateLimited,
  googleEmailUnsupported,
  invalidGoogleToken,
  unauthorized,
  network,
  server,

  /// Sign in worked, but the session could not be saved on this device.
  storage,
  unknown,
}

/// What the UI gets back. Like a TypeScript union.
sealed class AuthOutcome {
  const AuthOutcome();
}

final class AuthSuccess extends AuthOutcome {
  const AuthSuccess(this.user);

  final UserProfile user;
}

final class AuthFailure extends AuthOutcome {
  const AuthFailure({
    required this.kind,
    required this.message,
    this.fields,
    this.retryAfterSeconds,
  });

  final AuthFailureKind kind;

  /// Safe to show to the user.
  final String message;

  /// Form errors: field name -> message (`email`, `password`, `displayName`).
  final Map<String, String>? fields;

  /// Only for `rateLimited`.
  final int? retryAfterSeconds;
}
