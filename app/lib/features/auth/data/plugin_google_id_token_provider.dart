import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:apply_track/features/auth/data/google_id_token_provider.dart';

final class PluginGoogleIdTokenProvider implements GoogleIdTokenProvider {
  PluginGoogleIdTokenProvider({required String serverClientId})
    : _clientId = serverClientId;

  static const String _genericError =
      'Google sign-in failed. Please try again.';
  static const String _noTokenError =
      'Google did not give a sign-in token. Please try again.';

  /// The Web OAuth client ID (same as the backend `GoogleClientId`).
  /// Android uses it as `serverClientId`. Web uses it as `clientId`.
  final String _clientId;

  final StreamController<GoogleTokenResult> _tokens =
      StreamController<GoogleTokenResult>.broadcast();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  Future<void>? _initialization;

  bool get _isConfigured => _clientId.isNotEmpty;

  @override
  bool get usesRenderedButton => kIsWeb;

  @override
  Stream<GoogleTokenResult> get tokenEvents => _tokens.stream;

  /// Call when the provider is no longer needed.
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_tokens.close());
  }

  /// The plugin must be initialized exactly once. We do it on first use.
  Future<void> _ensureInitialized() async {
    final Future<void>? running = _initialization;
    if (running != null) return running;

    final Future<void> start = _initialize();
    _initialization = start;
    try {
      await start;
    } catch (_) {
      _initialization = null; // Allow a new try later.
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final GoogleSignIn signIn = GoogleSignIn.instance;
    if (kIsWeb) {
      // `serverClientId` is not supported on web.
      await signIn.initialize(clientId: _clientId);
      _events = signIn.authenticationEvents.listen(
        _onEvent,
        onError: _onEventError,
      );
    } else {
      await signIn.initialize(serverClientId: _clientId);
    }
  }

  @override
  Future<bool> prepare() async {
    if (!_isConfigured) return false;
    try {
      await _ensureInitialized();
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<GoogleTokenResult> getIdToken() async {
    if (!_isConfigured) {
      return const GoogleTokenFailed(
        'Google sign-in is not set up in this build.',
      );
    }
    try {
      await _ensureInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const GoogleTokenFailed(
          'Google sign-in is not available on this device.',
        );
      }
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      return _resultFor(account);
    } on GoogleSignInException catch (error) {
      return _resultForException(error);
    } on Exception {
      return const GoogleTokenFailed(_genericError);
    }
  }

  @override
  Future<void> signOut() async {
    if (!_isConfigured) return;
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } on Exception {
      // Best effort. The app session is already cleared.
    }
  }

  // ------------------------------------------------------------ web events

  void _onEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(
        :final GoogleSignInAccount user,
      ):
        _tokens.add(_resultFor(user));
      case GoogleSignInAuthenticationEventSignOut():
        break; // Nothing to do. Our own session is handled elsewhere.
    }
  }

  void _onEventError(Object error) {
    _tokens.add(
      error is GoogleSignInException
          ? _resultForException(error)
          : const GoogleTokenFailed(_genericError),
    );
  }

  // --------------------------------------------------------------- helpers

  GoogleTokenResult _resultFor(GoogleSignInAccount account) {
    final String? idToken = account.authentication.idToken; // no await
    if (idToken == null || idToken.isEmpty) {
      return const GoogleTokenFailed(_noTokenError);
    }
    return GoogleTokenOk(idToken);
  }

  GoogleTokenResult _resultForException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => const GoogleTokenCancelled(),
      _ => const GoogleTokenFailed(_genericError),
    };
  }
}
