/// Result of asking Google for an ID token. Like a TypeScript union.
/// The provider never throws.
sealed class GoogleTokenResult {
  const new();
}

final class GoogleTokenOk extends GoogleTokenResult {
  const new(this.idToken);

  /// Send this to the server as `credential`. Not the access token.
  final String idToken;
}

/// The user closed the dialog. This is not an error.
final class GoogleTokenCancelled extends GoogleTokenResult {
  const new();
}

final class GoogleTokenFailed extends GoogleTokenResult {
  const new(this.message);

  /// Safe to show to the user.
  final String message;
}

abstract interface class GoogleIdTokenProvider {
  /// `true` on web. Google draws its own button there, and the token
  /// arrives on [tokenEvents]. `false` on mobile: use [getIdToken].
  bool get usesRenderedButton;

  /// Web only: a token (or an error) after the user used Google's button.
  /// Never emits on mobile.
  Stream<GoogleTokenResult> get tokenEvents;

  /// Starts the plugin. Google's web button cannot show before this ends.
  /// Returns `false` if the plugin could not start. Never throws.
  Future<bool> prepare();

  /// Mobile: opens the Google account picker and returns an ID token.
  Future<GoogleTokenResult> getIdToken();

  /// Signs out of Google on this device. Best effort, never throws.
  Future<void> signOut();
}
