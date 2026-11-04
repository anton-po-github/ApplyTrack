import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:apply_track/core/api/api_error.dart';

Map<String, Object?> parse(String json) =>
    jsonDecode(json) as Map<String, Object?>;

void main() {
  group('ApiError.fromJson', () {
    test('reads code, message and fields', () {
      final ApiError error = ApiError.fromJson(
        parse(
          '{"code":"validation","message":"Please fix the fields.",'
          '"fields":{"title":"Title is required."}}',
        ),
      );
      expect(error.code, ApiErrorCodes.validation);
      expect(error.message, 'Please fix the fields.');
      expect(error.fields, <String, String>{'title': 'Title is required.'});
    });

    test('missing or wrong types fall back to unknown_error', () {
      final ApiError error = ApiError.fromJson(
        parse('{"code":5,"message":null}'),
      );
      expect(error.code, ApiErrorCodes.unknown);
      expect(error.message, 'Something went wrong.');
      expect(error.fields, isNull);
    });

    test('fields ignores values that are not strings', () {
      final ApiError error = ApiError.fromJson(
        parse('{"code":"validation","fields":{"email":"Bad.","x":1}}'),
      );
      expect(error.fields, <String, String>{'email': 'Bad.'});
    });

    test('empty fields become null', () {
      final ApiError error = ApiError.fromJson(
        parse('{"code":"validation","fields":{}}'),
      );
      expect(error.fields, isNull);
    });

    test('keeps retryAfterSeconds', () {
      final ApiError error = ApiError.fromJson(
        parse('{"code":"rate_limited"}'),
        retryAfterSeconds: 30,
      );
      expect(error.retryAfterSeconds, 30);
    });
  });

  test('client-only errors have their own codes', () {
    expect(const ApiError.network().code, ApiErrorCodes.network);
    expect(const ApiError.unauthorized().code, ApiErrorCodes.unauthorized);
    expect(const ApiError.badResponse().code, ApiErrorCodes.badResponse);
  });
}
