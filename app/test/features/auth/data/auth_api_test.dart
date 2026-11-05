import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/data/auth_api.dart';
import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';

final class _FakeClient implements ApiClient {
  String? method;
  String? path;
  Map<String, Object?>? body;
  bool? requiresAuth;
  Map<String, Object?> json = <String, Object?>{};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? query,
    bool requiresAuth = true,
  }) async {
    method = 'GET';
    this.path = path;
    this.requiresAuth = requiresAuth;
    return ApiOk<T>(parse(json));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) async {
    method = 'POST';
    this.path = path;
    this.body = body;
    this.requiresAuth = requiresAuth;
    return ApiOk<T>(parse(json));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) => throw UnimplementedError('The auth API does not use PUT');

  @override
  Future<ApiResult<void>> delete(String path, {bool requiresAuth = true}) =>
      throw UnimplementedError('The auth API does not use DELETE');
}

void main() {
  late _FakeClient client;
  late HttpAuthApi api;

  setUp(() {
    client = _FakeClient();
    api = HttpAuthApi(client);
  });

  final Map<String, Object?> authJson = <String, Object?>{
    'token': 'tok',
    'expiresAtUnixSeconds': 1767225600,
    'user': <String, Object?>{
      'id': 'u1',
      'email': 'a@b.com',
      'displayName': 'Anton',
    },
  };

  test('signup: path, body, no auth', () async {
    client.json = authJson;

    final ApiResult<AuthResponse> r = await api.signup(
      email: 'a@b.com',
      password: 'pw123456',
      displayName: 'Anton',
    );

    expect(r, isA<ApiOk<AuthResponse>>());
    expect(client.method, 'POST');
    expect(client.path, '/api/auth/signup');
    expect(client.requiresAuth, isFalse);
    expect(client.body, <String, Object?>{
      'email': 'a@b.com',
      'password': 'pw123456',
      'displayName': 'Anton',
    });
  });

  test('signin: path, body, no auth', () async {
    client.json = authJson;

    await api.signin(email: 'a@b.com', password: 'pw123456');

    expect(client.method, 'POST');
    expect(client.path, '/api/auth/signin');
    expect(client.requiresAuth, isFalse);
    expect(client.body, <String, Object?>{
      'email': 'a@b.com',
      'password': 'pw123456',
    });
  });

  test('google: sends the id token as "credential"', () async {
    client.json = authJson;

    await api.google(idToken: 'google-id-token');

    expect(client.method, 'POST');
    expect(client.path, '/api/auth/google');
    expect(client.requiresAuth, isFalse);
    expect(client.body, <String, Object?>{'credential': 'google-id-token'});
  });

  test('me: GET with auth', () async {
    client.json = <String, Object?>{
      'id': 'u1',
      'email': 'a@b.com',
      'displayName': 'Anton',
    };

    final ApiResult<UserProfile> r = await api.me();

    expect((r as ApiOk<UserProfile>).value.displayName, 'Anton');
    expect(client.method, 'GET');
    expect(client.path, '/api/auth/me');
    expect(client.requiresAuth, isTrue);
  });
}
