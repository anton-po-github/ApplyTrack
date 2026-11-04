import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/auth/data/auth_repository.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';

const UserProfile _user = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  displayName: 'Anton',
);

final DateTime _now = DateTime.utc(2026, 1, 1);
final int _nowSeconds = _now.millisecondsSinceEpoch ~/ 1000;

final Session _validSession = Session(
  token: 'tok',
  expiresAtUnixSeconds: _nowSeconds + 3600,
);
final Session _expiredSession = Session(
  token: 'tok',
  expiresAtUnixSeconds: _nowSeconds - 1,
);

const AuthFailure _network = AuthFailure(
  kind: AuthFailureKind.network,
  message: 'No connection.',
);

final class _FakeRepo implements AuthRepository {
  Session? session;
  AuthOutcome meOutcome = const AuthSuccess(_user);
  AuthOutcome authOutcome = const AuthSuccess(_user);
  Completer<AuthOutcome>? meGate;
  Completer<AuthOutcome>? authGate;
  Exception? authThrows;
  Exception? signOutThrows;

  int meCalls = 0;
  int signInCalls = 0;
  int signOutCalls = 0;
  Map<String, String> lastArgs = <String, String>{};

  Future<AuthOutcome> _auth() async {
    final Exception? error = authThrows;
    if (error != null) throw error;
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
  Future<AuthOutcome> signInWithGoogle({required String idToken}) {
    lastArgs = <String, String>{'idToken': idToken};
    return _auth();
  }

  @override
  Future<AuthOutcome> me() async {
    meCalls++;
    final Completer<AuthOutcome>? gate = meGate;
    if (gate != null) return gate.future;
    return meOutcome;
  }

  @override
  Future<Session?> readSession() async => session;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final Exception? error = signOutThrows;
    if (error != null) throw error;
    session = null;
  }
}

ProviderContainer _makeContainer(_FakeRepo repo) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Creates the controller and waits until the start check is done.
Future<ProviderContainer> _start(_FakeRepo repo) async {
  final ProviderContainer container = _makeContainer(repo);
  container.read(authControllerProvider);
  await pumpEventQueue();
  return container;
}

AuthState _stateOf(ProviderContainer c) => c.read(authControllerProvider);
AuthController _controllerOf(ProviderContainer c) =>
    c.read(authControllerProvider.notifier);
bool _busyOf(ProviderContainer c) => c.read(authBusyProvider);
AuthFailure _failureOf(AuthOutcome o) => o as AuthFailure;

void main() {
  group('start', () {
    test('begins as Unknown', () {
      final ProviderContainer c = _makeContainer(_FakeRepo());
      expect(_stateOf(c), isA<AuthUnknown>());
    });

    test('no session -> SignedOut, no server call', () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer c = await _start(repo);

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.meCalls, 0);
      expect(_busyOf(c), isFalse);
    });

    test('expired session -> SignedOut, session cleared, no /me', () async {
      final _FakeRepo repo = _FakeRepo()..session = _expiredSession;
      final ProviderContainer c = await _start(repo);

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.signOutCalls, 1);
      expect(repo.meCalls, 0);
    });

    test('valid session + /me ok -> SignedIn', () async {
      final _FakeRepo repo = _FakeRepo()..session = _validSession;
      final ProviderContainer c = await _start(repo);

      final AuthState state = _stateOf(c);
      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).user, _user);
      expect(repo.signOutCalls, 0);
    });

    test('valid session + /me 401 -> SignedOut and cleared', () async {
      final _FakeRepo repo = _FakeRepo()
        ..session = _validSession
        ..meOutcome = const AuthFailure(
          kind: AuthFailureKind.unauthorized,
          message: 'Please sign in again.',
        );
      final ProviderContainer c = await _start(repo);

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.signOutCalls, 1);
    });

    test('no network -> Unavailable, token is kept', () async {
      final _FakeRepo repo = _FakeRepo()
        ..session = _validSession
        ..meOutcome = _network;
      final ProviderContainer c = await _start(repo);

      expect(_stateOf(c), isA<AuthUnavailable>());
      expect(repo.signOutCalls, 0);
      expect(repo.session, _validSession);
    });

    test('server error -> Unavailable, token is kept', () async {
      final _FakeRepo repo = _FakeRepo()
        ..session = _validSession
        ..meOutcome = const AuthFailure(
          kind: AuthFailureKind.server,
          message: 'Server problem.',
        );
      final ProviderContainer c = await _start(repo);

      expect(_stateOf(c), isA<AuthUnavailable>());
      expect(repo.signOutCalls, 0);
    });

    test(
      'restore (Retry) leaves Unavailable when the network is back',
      () async {
        final _FakeRepo repo = _FakeRepo()
          ..session = _validSession
          ..meOutcome = _network;
        final ProviderContainer c = await _start(repo);
        expect(_stateOf(c), isA<AuthUnavailable>());

        repo.meOutcome = const AuthSuccess(_user);
        await _controllerOf(c).restore();

        expect(_stateOf(c), isA<AuthSignedIn>());
        expect(_busyOf(c), isFalse);
      },
    );

    test('broken storage on read -> SignedOut', () async {
      final ProviderContainer c = _makeContainer(_ThrowingReadRepo());
      c.read(authControllerProvider);
      await pumpEventQueue();

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(_busyOf(c), isFalse);
    });
  });

  group('actions', () {
    test('signIn success -> SignedIn', () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer c = await _start(repo);

      final AuthOutcome o = await _controllerOf(c)
          .signIn(email: 'a@b.com', password: 'pw123456');

      expect(o, isA<AuthSuccess>());
      expect(_stateOf(c), isA<AuthSignedIn>());
      expect(repo.lastArgs['email'], 'a@b.com');
      expect(_busyOf(c), isFalse);
    });

    test('signUp success -> SignedIn', () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer c = await _start(repo);

      final AuthOutcome o = await _controllerOf(c)
          .signUp(email: 'a@b.com', password: 'pw123456', displayName: 'Anton');

      expect(o, isA<AuthSuccess>());
      expect(_stateOf(c), isA<AuthSignedIn>());
      expect(repo.lastArgs['displayName'], 'Anton');
    });

    test('Google success -> SignedIn', () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer c = await _start(repo);

      final AuthOutcome o = await _controllerOf(c)
          .signInWithGoogle(idToken: 'g-token');

      expect(o, isA<AuthSuccess>());
      expect(_stateOf(c), isA<AuthSignedIn>());
      expect(repo.lastArgs['idToken'], 'g-token');
    });

    test('failure keeps SignedOut and returns the form fields', () async {
      final _FakeRepo repo = _FakeRepo()
        ..authOutcome = const AuthFailure(
          kind: AuthFailureKind.validation,
          message: 'Please fix the fields.',
          fields: <String, String>{'email': 'Bad email.'},
        );
      final ProviderContainer c = await _start(repo);

      final AuthFailure f = _failureOf(
        await _controllerOf(c).signIn(email: 'x', password: 'y'),
      );

      expect(f.kind, AuthFailureKind.validation);
      expect(f.fields, <String, String>{'email': 'Bad email.'});
      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(_busyOf(c), isFalse);
    });

    test('a double tap runs only one call', () async {
      final _FakeRepo repo = _FakeRepo()..authGate = Completer<AuthOutcome>();
      final ProviderContainer c = await _start(repo);
      final AuthController controller = _controllerOf(c);

      final Future<AuthOutcome> first = controller.signIn(
        email: 'a@b.com',
        password: 'pw123456',
      );
      expect(_busyOf(c), isTrue);

      final AuthFailure second = _failureOf(
        await controller.signIn(email: 'a@b.com', password: 'pw123456'),
      );
      expect(second.kind, AuthFailureKind.busy);

      repo.authGate!.complete(const AuthSuccess(_user));
      expect(await first, isA<AuthSuccess>());

      expect(repo.signInCalls, 1);
      expect(_busyOf(c), isFalse);
      expect(_stateOf(c), isA<AuthSignedIn>());
    });

    test('actions are blocked while the start check runs', () async {
      final _FakeRepo repo = _FakeRepo()
        ..session = _validSession
        ..meGate = Completer<AuthOutcome>();
      final ProviderContainer c = _makeContainer(repo);
      c.read(authControllerProvider);
      await pumpEventQueue();

      expect(_stateOf(c), isA<AuthUnknown>());
      expect(_busyOf(c), isTrue);

      final AuthFailure f = _failureOf(
        await _controllerOf(c).signIn(email: 'a@b.com', password: 'pw123456'),
      );
      expect(f.kind, AuthFailureKind.busy);
      expect(repo.signInCalls, 0);

      repo.meGate!.complete(const AuthSuccess(_user));
      await pumpEventQueue();

      expect(_stateOf(c), isA<AuthSignedIn>());
      expect(_busyOf(c), isFalse);
    });

    test(
      'an unexpected exception becomes a failure and frees the lock',
      () async {
        final _FakeRepo repo = _FakeRepo()..authThrows = Exception('boom');
        final ProviderContainer c = await _start(repo);

        final AuthFailure f = _failureOf(
          await _controllerOf(c).signIn(email: 'a@b.com', password: 'pw123456'),
        );

        expect(f.kind, AuthFailureKind.unknown);
        expect(_busyOf(c), isFalse);
        expect(_stateOf(c), isA<AuthSignedOut>());
      },
    );
  });

  group('sign out', () {
    test('signOut -> SignedOut and the session is cleared', () async {
      final _FakeRepo repo = _FakeRepo()..session = _validSession;
      final ProviderContainer c = await _start(repo);
      expect(_stateOf(c), isA<AuthSignedIn>());

      await _controllerOf(c).signOut();

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.signOutCalls, 1);
      expect(_busyOf(c), isFalse);
    });

    test('signOut still ends signed out when the storage fails', () async {
      final _FakeRepo repo = _FakeRepo()
        ..session = _validSession
        ..signOutThrows = Exception('disk');
      final ProviderContainer c = await _start(repo);

      await _controllerOf(c).signOut();

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(_busyOf(c), isFalse);
    });
  });

  group('global 401', () {
    test('signs a signed-in user out and clears the session', () async {
      final _FakeRepo repo = _FakeRepo()..session = _validSession;
      final ProviderContainer c = await _start(repo);
      expect(_stateOf(c), isA<AuthSignedIn>());

      c.read(unauthorizedSignalProvider.notifier).notify();
      await pumpEventQueue();

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.signOutCalls, 1);
    });

    test('is ignored when the user is already signed out', () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer c = await _start(repo);

      c.read(unauthorizedSignalProvider.notifier).notify();
      await pumpEventQueue();

      expect(_stateOf(c), isA<AuthSignedOut>());
      expect(repo.signOutCalls, 0);
    });
  });
}

final class _ThrowingReadRepo extends _FakeRepo {
  @override
  Future<Session?> readSession() async => throw Exception('storage broken');
}
