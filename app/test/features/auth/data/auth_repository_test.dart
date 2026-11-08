import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/data/auth_api.dart';
import 'package:apply_track/features/auth/data/auth_repository.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

const UserProfile _user = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  displayName: 'Anton',
);

const AuthResponse _response = AuthResponse(
  token: 'tok',
  expiresAtUnixSeconds: 1767225600,
  user: _user,
);

final class _FakeAuthApi implements AuthApi {
  ApiResult<AuthResponse> authResult = const ApiOk<AuthResponse>(_response);
  ApiResult<UserProfile> meResult = const ApiOk<UserProfile>(_user);
  String? lastCall;
  Map<String, String> lastArgs = <String, String>{};

  @override
  Future<ApiResult<AuthResponse>> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    lastCall = 'signup';
    lastArgs = <String, String>{
      'email': email,
      'password': password,
      'displayName': displayName,
    };
    return authResult;
  }

  @override
  Future<ApiResult<AuthResponse>> signin({
    required String email,
    required String password,
  }) async {
    lastCall = 'signin';
    lastArgs = <String, String>{'email': email, 'password': password};
    return authResult;
  }

  @override
  Future<ApiResult<AuthResponse>> google({required String idToken}) async {
    lastCall = 'google';
    lastArgs = <String, String>{'idToken': idToken};
    return authResult;
  }

  @override
  Future<ApiResult<UserProfile>> me() async => meResult;
}

final class _FailingWriteStorage implements TokenStorage {
  int clears = 0;

  @override
  Future<Session?> read() async => null;

  @override
  Future<void> write(Session session) async => throw Exception('disk full');

  @override
  Future<void> clear() async => clears++;
}

AuthFailure _failureOf(AuthOutcome outcome) => outcome as AuthFailure;

void main() {
  late _FakeAuthApi api;
  late InMemoryTokenStorage storage;
  late DefaultAuthRepository repo;

  setUp(() {
    api = _FakeAuthApi();
    storage = InMemoryTokenStorage();
    repo = DefaultAuthRepository(api: api, storage: storage);
  });

  const expectedSession = Session(
    token: 'tok',
    expiresAtUnixSeconds: 1767225600,
  );

  group('success', () {
    test('signUp cleans email and name, keeps the password, saves', () async {
      final o = await repo.signUp(
        email: '  Anton@Example.COM ',
        password: '  my pass 123  ',
        displayName: '  Anton  ',
      );

      expect((o as AuthSuccess).user, _user);
      expect(api.lastCall, 'signup');
      expect(api.lastArgs, <String, String>{
        'email': 'anton@example.com',
        'password': '  my pass 123  ',
        'displayName': 'Anton',
      });
      expect(await storage.read(), expectedSession);
    });

    test('signIn cleans the email and saves the session', () async {
      final o = await repo.signIn(email: ' A@B.com ', password: 'pw123456');

      expect(o, isA<AuthSuccess>());
      expect(api.lastCall, 'signin');
      expect(api.lastArgs['email'], 'a@b.com');
      expect(await storage.read(), expectedSession);
    });

    test('signInWithGoogle sends the token as it is and saves', () async {
      final o = await repo.signInWithGoogle(idToken: 'g-token');

      expect(o, isA<AuthSuccess>());
      expect(api.lastCall, 'google');
      expect(api.lastArgs['idToken'], 'g-token');
      expect(await storage.read(), expectedSession);
    });

    test('me returns the user and does not touch the session', () async {
      await storage.write(expectedSession);

      final o = await repo.me();

      expect((o as AuthSuccess).user, _user);
      expect(await storage.read(), expectedSession);
    });

    test('signOut clears the session', () async {
      await storage.write(expectedSession);
      await repo.signOut();
      expect(await storage.read(), isNull);
    });
  });

  group('failure', () {
    test('a failed sign in does not save anything', () async {
      api.authResult = const ApiErr<AuthResponse>(
        ApiError(
          code: ApiErrorCodes.invalidCredentials,
          message: 'server text',
        ),
      );

      final f = _failureOf(await repo.signIn(email: 'a@b.com', password: 'x'));

      expect(f.kind, AuthFailureKind.invalidCredentials);
      expect(f.message, 'Wrong email or password.');
      expect(await storage.read(), isNull);
    });

    test('validation keeps the server fields', () async {
      api.authResult = const ApiErr<AuthResponse>(
        ApiError(
          code: ApiErrorCodes.validation,
          message: 'Please fix the fields.',
          fields: <String, String>{'password': 'Too short.'},
        ),
      );

      final f = _failureOf(
        await repo.signUp(email: 'a@b.com', password: 'x', displayName: 'A'),
      );

      expect(f.kind, AuthFailureKind.validation);
      expect(f.fields, <String, String>{'password': 'Too short.'});
    });

    test('email_taken always has an email field error', () async {
      api.authResult = const ApiErr<AuthResponse>(
        ApiError(code: ApiErrorCodes.emailTaken, message: 'x'),
      );

      final f = _failureOf(
        await repo.signUp(
          email: 'a@b.com',
          password: 'pw123456',
          displayName: 'A',
        ),
      );

      expect(f.kind, AuthFailureKind.emailTaken);
      expect(f.fields?['email'], isNotEmpty);
    });

    test('rate_limited shows the seconds', () async {
      api.authResult = const ApiErr<AuthResponse>(
        ApiError(
          code: ApiErrorCodes.rateLimited,
          message: 'x',
          retryAfterSeconds: 12,
        ),
      );

      final f = _failureOf(await repo.signIn(email: 'a@b.com', password: 'x'));

      expect(f.kind, AuthFailureKind.rateLimited);
      expect(f.retryAfterSeconds, 12);
      expect(f.message, contains('12 seconds'));
    });

    test('rate_limited without seconds still has a message', () async {
      api.authResult = const ApiErr<AuthResponse>(
        ApiError(code: ApiErrorCodes.rateLimited, message: 'x'),
      );

      final f = _failureOf(await repo.signIn(email: 'a@b.com', password: 'x'));

      expect(f.retryAfterSeconds, isNull);
      expect(f.message, isNotEmpty);
    });

    final kinds = <String, AuthFailureKind>{
      ApiErrorCodes.googleEmailUnsupported:
          AuthFailureKind.googleEmailUnsupported,
      ApiErrorCodes.invalidGoogleToken: AuthFailureKind.invalidGoogleToken,
      ApiErrorCodes.unauthorized: AuthFailureKind.unauthorized,
      ApiErrorCodes.network: AuthFailureKind.network,
      ApiErrorCodes.serverError: AuthFailureKind.server,
      ApiErrorCodes.badResponse: AuthFailureKind.unknown,
      ApiErrorCodes.badRequest: AuthFailureKind.unknown,
      ApiErrorCodes.unknown: AuthFailureKind.unknown,
      'some_new_code': AuthFailureKind.unknown,
    };
    for (final entry in kinds.entries) {
      test('code ${entry.key} maps to ${entry.value}', () async {
        api.authResult = ApiErr<AuthResponse>(
          ApiError(code: entry.key, message: 'text'),
        );

        final f = _failureOf(await repo.signInWithGoogle(idToken: 'g'));

        expect(f.kind, entry.value);
        expect(f.message, isNotEmpty);
      });
    }

    test('me maps a 401 to unauthorized', () async {
      api.meResult = const ApiErr<UserProfile>(ApiError.unauthorized());

      final f = _failureOf(await repo.me());

      expect(f.kind, AuthFailureKind.unauthorized);
    });

    test('me maps no network to network', () async {
      api.meResult = const ApiErr<UserProfile>(ApiError.network());

      final f = _failureOf(await repo.me());

      expect(f.kind, AuthFailureKind.network);
    });
  });

  group('storage problems', () {
    test('a failed save is a storage failure and clears', () async {
      final broken = _FailingWriteStorage();
      final r = DefaultAuthRepository(api: api, storage: broken);

      final f = _failureOf(
        await r.signIn(email: 'a@b.com', password: 'pw123456'),
      );

      expect(f.kind, AuthFailureKind.storage);
      expect(broken.clears, 1);
    });
  });
}
