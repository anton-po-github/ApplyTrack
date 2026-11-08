import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';

/// Raw calls from 07-api-schema.md. No logic here.
abstract interface class AuthApi {
  Future<ApiResult<AuthResponse>> signup({
    required String email,
    required String password,
    required String displayName,
  });

  Future<ApiResult<AuthResponse>> signin({
    required String email,
    required String password,
  });

  Future<ApiResult<AuthResponse>> google({required String idToken});

  Future<ApiResult<UserProfile>> me();
}

final class HttpAuthApi implements AuthApi {
  const new(this._client);

  final ApiClient _client;

  @override
  Future<ApiResult<AuthResponse>> signup({
    required String email,
    required String password,
    required String displayName,
  }) => _client.post<AuthResponse>(
    '/api/auth/signup',
    requiresAuth: false,
    body: <String, Object?>{
      'email': email,
      'password': password,
      'displayName': displayName,
    },
    parse: AuthResponse.fromJson,
  );

  @override
  Future<ApiResult<AuthResponse>> signin({
    required String email,
    required String password,
  }) => _client.post<AuthResponse>(
    '/api/auth/signin',
    requiresAuth: false,
    body: <String, Object?>{'email': email, 'password': password},
    parse: AuthResponse.fromJson,
  );

  @override
  Future<ApiResult<AuthResponse>> google({required String idToken}) =>
      _client.post<AuthResponse>(
        '/api/auth/google',
        requiresAuth: false,
        body: <String, Object?>{'credential': idToken},
        parse: AuthResponse.fromJson,
      );

  @override
  Future<ApiResult<UserProfile>> me() =>
      _client.get<UserProfile>('/api/auth/me', parse: UserProfile.fromJson);
}
