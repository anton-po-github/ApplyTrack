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

  /// Another auth action is already running (double tap).
  busy,

  /// The user closed the Google dialog. The UI shows nothing.
  cancelled,

  /// The Google dialog or plugin failed (not our server).
  googleSignIn,
  unknown,
}

/// What the UI gets back. Like a TypeScript union.
sealed class AuthOutcome {
  const new();
}

final class AuthSuccess extends AuthOutcome {
  const new(this.user);

  final UserProfile user;
}

final class AuthFailure extends AuthOutcome {
  const new({
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
