import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/data/auth_api.dart';
import 'package:apply_track/features/auth/data/auth_repository.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';
import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';

final class _NoCallsApi implements AuthApi {
  @override
  Future<ApiResult<AuthResponse>> signup({
    required String email,
    required String password,
    required String displayName,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<AuthResponse>> signin({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<AuthResponse>> google({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<ApiResult<UserProfile>> me() => throw UnimplementedError();
}

void main() {
  test('readSession returns the saved session', () async {
    const Session saved = Session(token: 'tok', expiresAtUnixSeconds: 100);
    final DefaultAuthRepository repo = DefaultAuthRepository(
      api: _NoCallsApi(),
      storage: InMemoryTokenStorage(saved),
    );
    expect(await repo.readSession(), saved);
  });

  test('readSession returns null when nothing is saved', () async {
    final DefaultAuthRepository repo = DefaultAuthRepository(
      api: _NoCallsApi(),
      storage: InMemoryTokenStorage(),
    );
    expect(await repo.readSession(), isNull);
  });
}
