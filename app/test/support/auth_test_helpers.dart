import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/data/auth_repository.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';

const UserProfile testUser = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  displayName: 'Anton',
);

/// A session that is valid for one hour from now.
Session validSession() => Session(
  token: 'tok',
  expiresAtUnixSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
);

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.session});

  Session? session;
  AuthOutcome meOutcome = const AuthSuccess(testUser);
  AuthOutcome authOutcome = const AuthSuccess(testUser);

  /// Set it to keep sign in / sign up "loading" until you complete it.
  Completer<AuthOutcome>? authGate;

  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  Map<String, String> lastArgs = <String, String>{};

  Future<AuthOutcome> _auth() async {
    final Completer<AuthOutcome>? gate = authGate;
    if (gate != null) return gate.future;
    return authOutcome;
  }

  @override
  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    signUpCalls++;
    lastArgs = <String, String>{
      'email': email,
      'password': password,
      'displayName': displayName,
    };
    return _auth();
  }

  @override
  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) {
    signInCalls++;
    lastArgs = <String, String>{'email': email, 'password': password};
    return _auth();
  }

  @override
  Future<AuthOutcome> signInWithGoogle({required String idToken}) => _auth();

  @override
  Future<AuthOutcome> me() async => meOutcome;

  @override
  Future<Session?> readSession() async => session;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    session = null;
  }
}

/// Pumps one screen inside a ProviderScope with a fake repository.
/// It creates the auth controller first, so the start check is finished
/// before the test touches the form (the router does this in the real app).
Future<void> pumpAuthScreen(
  WidgetTester tester,
  FakeAuthRepository repo,
  Widget screen,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: screen),
    ),
  );
  ProviderScope.containerOf(tester.element(find.byWidget(screen)))
      .read(authControllerProvider);
  await tester.pumpAndSettle();
}
