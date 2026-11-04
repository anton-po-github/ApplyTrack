import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';

/// `true` while an auth action (or the start check) runs.
/// The UI watches it to disable buttons. The controller uses it as a lock.
final NotifierProvider<AuthBusy, bool> authBusyProvider =
    NotifierProvider<AuthBusy, bool>(AuthBusy.new);

class AuthBusy extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool value}) => state = value;
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  static const AuthFailure _busyFailure = AuthFailure(
    kind: AuthFailureKind.busy,
    message: 'Please wait a moment.',
  );

  static const AuthFailure _unexpectedFailure = AuthFailure(
    kind: AuthFailureKind.unknown,
    message: 'Something went wrong. Please try again.',
  );

  @override
  AuthState build() {
    // A 401 from any protected call signs the user out.
    ref.listen<int>(
      unauthorizedSignalProvider,
      (int? previous, int next) => unawaited(_handleUnauthorized()),
    );
    // Start the session check right after the first build.
    unawaited(Future<void>.microtask(restore));
    return const AuthUnknown();
  }

  // ---------------------------------------------------------------- start

  /// Checks the saved session. Also used by the Retry button.
  Future<void> restore() async {
    if (!_begin()) return;
    try {
      state = const AuthUnknown();
      final AuthState next = await _resolveStartState();
      if (ref.mounted) state = next;
    } finally {
      _end();
    }
  }

  Future<AuthState> _resolveStartState() async {
    final Session? session;
    try {
      session = await ref.read(authRepositoryProvider).readSession();
    } on Exception {
      return const AuthSignedOut(); // Broken storage = no session.
    }
    if (session == null) return const AuthSignedOut();

    if (session.isExpired(ref.read(clockProvider)())) {
      await _clearSession();
      return const AuthSignedOut();
    }

    final AuthOutcome outcome;
    try {
      outcome = await ref.read(authRepositoryProvider).me();
    } on Exception {
      return const AuthUnavailable();
    }
    switch (outcome) {
      case AuthSuccess(:final UserProfile user):
        return AuthSignedIn(user);
      case AuthFailure(kind: AuthFailureKind.unauthorized):
        await _clearSession();
        return const AuthSignedOut();
      case AuthFailure():
        // No network, server error, anything else: keep the token.
        return const AuthUnavailable();
    }
  }

  // -------------------------------------------------------------- actions

  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _runAction(
    () => ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, displayName: displayName),
  );

  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) => _runAction(
    () => ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password),
  );

  Future<AuthOutcome> signInWithGoogle({required String idToken}) => _runAction(
    () => ref.read(authRepositoryProvider).signInWithGoogle(idToken: idToken),
  );

  /// Always ends signed out, even if the device storage fails.
  /// Does nothing while another action runs.
  Future<void> signOut() async {
    if (!_begin()) return;
    try {
      state = const AuthSignedOut();
      await _clearSession();
    } finally {
      _end();
    }
  }

  Future<AuthOutcome> _runAction(Future<AuthOutcome> Function() action) async {
    if (!_begin()) return _busyFailure;
    try {
      final AuthOutcome outcome = await action();
      if (ref.mounted && outcome is AuthSuccess) {
        state = AuthSignedIn(outcome.user);
      }
      return outcome;
    } on Exception {
      return _unexpectedFailure;
    } finally {
      _end();
    }
  }

  // ------------------------------------------------------------- 401 flow

  /// Only a signed-in user can lose a session this way.
  /// (During start, `restore` handles the 401 itself.)
  Future<void> _handleUnauthorized() async {
    if (state is! AuthSignedIn) return;
    state = const AuthSignedOut(); // Leave the screen at once.
    await _clearSession();
  }

  // -------------------------------------------------------------- helpers

  Future<void> _clearSession() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Exception {
      // The user is signed out in memory. Nothing more we can do.
    }
  }

  /// The lock. Runs without any `await`, so two fast taps cannot both pass.
  bool _begin() {
    if (!ref.mounted) return false;
    if (ref.read(authBusyProvider)) return false;
    ref.read(authBusyProvider.notifier).set(value: true);
    return true;
  }

  void _end() {
    if (ref.mounted) ref.read(authBusyProvider.notifier).set(value: false);
  }
}
