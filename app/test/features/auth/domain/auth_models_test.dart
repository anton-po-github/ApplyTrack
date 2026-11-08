import 'dart:convert';

import 'package:apply_track/features/auth/domain/auth_response.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> parse(String json) =>
    jsonDecode(json) as Map<String, Object?>;

const String _user = '{"id":"u1","email":"a@b.com","displayName":"Anton"}';

void main() {
  group('UserProfile.fromJson', () {
    test('reads all fields', () {
      final user = UserProfile.fromJson(parse(_user));
      expect(user.id, 'u1');
      expect(user.email, 'a@b.com');
      expect(user.displayName, 'Anton');
    });

    test('missing field throws', () {
      expect(
        () => UserProfile.fromJson(parse('{"id":"u1","email":"a@b.com"}')),
        throwsFormatException,
      );
    });

    test('wrong type throws', () {
      expect(
        () => UserProfile.fromJson(
          parse('{"id":1,"email":"a@b.com","displayName":"A"}'),
        ),
        throwsFormatException,
      );
    });
  });

  group('AuthResponse.fromJson', () {
    test('reads token, expiry and user', () {
      final response = AuthResponse.fromJson(
        parse(
          '{"token":"secret-token","expiresAtUnixSeconds":1767225600,'
          ' "user":$_user}',
        ),
      );
      expect(response.token, 'secret-token');
      expect(response.expiresAtUnixSeconds, 1767225600);
      expect(response.user.displayName, 'Anton');
    });

    test('empty token throws', () {
      expect(
        () => AuthResponse.fromJson(
          parse('{"token":"","expiresAtUnixSeconds":1,"user":$_user}'),
        ),
        throwsFormatException,
      );
    });

    test('missing user throws', () {
      expect(
        () => AuthResponse.fromJson(
          parse('{"token":"t","expiresAtUnixSeconds":1}'),
        ),
        throwsFormatException,
      );
    });

    test('expiry as a string throws', () {
      expect(
        () => AuthResponse.fromJson(
          parse('{"token":"t","expiresAtUnixSeconds":"1","user":$_user}'),
        ),
        throwsFormatException,
      );
    });

    test('toString never shows the token', () {
      final response = AuthResponse.fromJson(
        parse(
          '{"token":"secret-token","expiresAtUnixSeconds":1,"user":$_user}',
        ),
      );
      expect(response.toString(), isNot(contains('secret-token')));
    });
  });
}
