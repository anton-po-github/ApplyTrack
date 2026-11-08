import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/data/auth_api.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/auth_validators.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';

/// An interface, so the controller (Step 5) can use a fake in tests.
abstract interface class AuthRepository {
  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthOutcome> signIn({required String email, required String password});

  Future<AuthOutcome> signInWithGoogle({required String idToken});

  /// Current user from the server. It does not change the saved session.
  Future<AuthOutcome> me();

  /// The saved session, or null. Does not call the server.
  Future<Session?> readSession();

  /// Deletes the saved session. Can throw if the device storage fails.
  Future<void> signOut();
}

final class DefaultAuthRepository implements AuthRepository {
  const new({required this._api, required this._storage});

  final AuthApi _api;
  final TokenStorage _storage;

  @override
  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _authenticate(
    _api.signup(
      email: AuthValidators.normalizeEmail(email),
      // The password is sent exactly as typed. Never trim it.
      password: password,
      displayName: displayName.trim(),
    ),
  );

  @override
  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) => _authenticate(
    _api.signin(
      email: AuthValidators.normalizeEmail(email),
      password: password,
    ),
  );

  @override
  Future<AuthOutcome> signInWithGoogle({required String idToken}) =>
      _authenticate(_api.google(idToken: idToken));

  @override
  Future<AuthOutcome> me() async {
    final result = await _api.me();
    return switch (result) {
      ApiOk<UserProfile>(:final UserProfile value) => AuthSuccess(value),
      ApiErr<UserProfile>(:final ApiError error) => _failure(error),
    };
  }

  @override
  Future<Session?> readSession() => _storage.read();

  @override
  Future<void> signOut() => _storage.clear();

  Future<AuthOutcome> _authenticate(
    Future<ApiResult<AuthResponse>> call,
  ) async {
    final result = await call;
    switch (result) {
      case ApiErr<AuthResponse>(:final ApiError error):
        return _failure(error);
      case ApiOk<AuthResponse>(:final AuthResponse value):
        try {
          await _storage.write(
            Session(
              token: value.token,
              expiresAtUnixSeconds: value.expiresAtUnixSeconds,
            ),
          );
        } on Exception {
          await _tryClear();
          return const AuthFailure(
            kind: AuthFailureKind.storage,
            message: 'Could not save your session on this device.',
          );
        }
        return AuthSuccess(value.user);
    }
  }

  Future<void> _tryClear() async {
    try {
      await _storage.clear();
    } on Exception {
      // Nothing more we can do.
    }
  }

  static AuthFailure _failure(ApiError error) {
    switch (error.code) {
      case ApiErrorCodes.validation:
        return AuthFailure(
          kind: AuthFailureKind.validation,
          message: error.message,
          fields: error.fields,
        );
      case ApiErrorCodes.emailTaken:
        const text = 'This email is already used.';
        return AuthFailure(
          kind: AuthFailureKind.emailTaken,
          message: text,
          fields: error.fields ?? const <String, String>{'email': text},
        );
      case ApiErrorCodes.invalidCredentials:
        return const AuthFailure(
          kind: AuthFailureKind.invalidCredentials,
          message: 'Wrong email or password.',
        );
      case ApiErrorCodes.rateLimited:
        final seconds = error.retryAfterSeconds;
        return AuthFailure(
          kind: AuthFailureKind.rateLimited,
          message: seconds == null
              ? 'Too many tries. Please wait a little and try again.'
              : 'Too many tries. Please wait $seconds '
                    '${seconds == 1 ? 'second' : 'seconds'} and try again.',
          retryAfterSeconds: seconds,
        );
      case ApiErrorCodes.googleEmailUnsupported:
        return const AuthFailure(
          kind: AuthFailureKind.googleEmailUnsupported,
          message: 'This Google email cannot be used.',
        );
      case ApiErrorCodes.invalidGoogleToken:
        return const AuthFailure(
          kind: AuthFailureKind.invalidGoogleToken,
          message: 'Google sign-in failed. Please try again.',
        );
      case ApiErrorCodes.unauthorized:
        return const AuthFailure(
          kind: AuthFailureKind.unauthorized,
          message: 'Please sign in again.',
        );
      case ApiErrorCodes.network:
        return AuthFailure(
          kind: AuthFailureKind.network,
          message: error.message,
        );
      case ApiErrorCodes.serverError:
        return const AuthFailure(
          kind: AuthFailureKind.server,
          message: 'Server problem. Please try again later.',
        );
      default:
        return AuthFailure(
          kind: AuthFailureKind.unknown,
          message: error.message,
        );
    }
  }
}
