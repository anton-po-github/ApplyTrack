import 'package:apply_track/features/auth/domain/user_profile.dart';

/// Who is using the app right now. Like a TypeScript union.
sealed class AuthState {
  const AuthState();
}

/// App just started. We are still checking the saved session.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final UserProfile user;
}

/// We have a saved session, but the server did not answer
/// (no network, server error). The token is kept. The UI shows Retry.
final class AuthUnavailable extends AuthState {
  const AuthUnavailable();
}
