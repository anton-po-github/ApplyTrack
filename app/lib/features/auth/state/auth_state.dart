import 'package:apply_track/features/auth/domain/user_profile.dart';

/// Who is using the app right now. Like a TypeScript union.
sealed class AuthState {
  const new();
}

/// App just started. We are still checking the saved session.
final class AuthUnknown extends AuthState {
  const new();
}

final class AuthSignedOut extends AuthState {
  const new();
}

final class AuthSignedIn extends AuthState {
  const new(this.user);

  final UserProfile user;
}

/// We have a saved session, but the server did not answer
/// (no network, server error). The token is kept. The UI shows Retry.
final class AuthUnavailable extends AuthState {
  const new();
}
