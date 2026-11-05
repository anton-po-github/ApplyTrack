import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/api/dio_api_client.dart';
import 'package:apply_track/core/api/json_fields.dart';
import 'package:apply_track/core/api/token_reader.dart';

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _Handler _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _FakeTokenReader implements TokenReader {
  _FakeTokenReader(this.token);

  final String? token;
  int calls = 0;

  @override
  Future<String?> readToken() async {
    calls++;
    return token;
  }
}

ResponseBody _json(String body, int status, {Map<String, List<String>>? h}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        ...?h,
      },
    );

String _parseName(Map<String, Object?> json) => json.requireString('name');

void main() {
  late _FakeAdapter adapter;
  late _FakeTokenReader tokens;
  late int unauthorizedCalls;
  late DioApiClient client;

  void setUpClient(_Handler handler, {String? token = 'tok-123'}) {
    adapter = _FakeAdapter(handler);
    tokens = _FakeTokenReader(token);
    unauthorizedCalls = 0;
    client = DioApiClient(
      baseUrl: 'https://example.test',
      tokenReader: tokens,
      onUnauthorized: () => unauthorizedCalls++,
      httpClientAdapter: adapter,
    );
  }

  ApiError errorOf(ApiResult<String> r) => (r as ApiErr<String>).error;

  group('success', () {
    test('GET parses JSON and sends the Bearer header', () async {
      setUpClient((_) async => _json('{"name":"Anton"}', 200));

      final ApiResult<String> r = await client.get<String>(
        '/api/auth/me',
        parse: _parseName,
      );

      expect((r as ApiOk<String>).value, 'Anton');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.uri.toString(), 'https://example.test/api/auth/me');
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect(sent.followRedirects, isFalse);
    });

    test('POST sends the JSON body and accepts 201', () async {
      setUpClient((_) async => _json('{"name":"ok"}', 201));

      final ApiResult<String> r = await client.post<String>(
        '/api/proposals',
        body: <String, Object?>{'title': 'Hello'},
        parse: _parseName,
      );

      expect(r, isA<ApiOk<String>>());
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(sent.data, <String, Object?>{'title': 'Hello'});
      expect(sent.contentType, startsWith('application/json'));
    });

    test('query: null values are removed, others are sent', () async {
      setUpClient((_) async => _json('{"name":"ok"}', 200));

      await client.get<String>(
        '/api/proposals',
        query: <String, Object?>{'status': 3, 'q': null, 'limit': 20},
        parse: _parseName,
      );

      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'status': '3',
        'limit': '20',
      });
    });
  });

  group('PUT and DELETE', () {
    test('PUT sends the JSON body with the Bearer header', () async {
      setUpClient((_) async => _json('{"name":"updated"}', 200));

      final ApiResult<String> r = await client.put<String>(
        '/api/proposals/abc',
        body: <String, Object?>{'title': 'New', 'company': null},
        parse: _parseName,
      );

      expect((r as ApiOk<String>).value, 'updated');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'PUT');
      expect(sent.uri.toString(), 'https://example.test/api/proposals/abc');
      // A null value stays in the body: PUT is a full replace.
      expect(sent.data, <String, Object?>{'title': 'New', 'company': null});
      expect(sent.headers['Authorization'], 'Bearer tok-123');
    });

    test('PUT 400 validation keeps the fields', () async {
      setUpClient(
        (_) async => _json(
          '{"code":"validation","message":"Fix it.",'
          '"fields":{"title":"Title is required."}}',
          400,
        ),
      );

      final ApiError e = errorOf(
        await client.put<String>('/api/proposals/abc', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.validation);
      expect(e.fields, <String, String>{'title': 'Title is required.'});
      expect(unauthorizedCalls, 0);
    });

    test('DELETE 204 with no body is success', () async {
      setUpClient((_) async => _json('', 204));

      final ApiResult<void> r = await client.delete('/api/proposals/abc');

      expect(r, isA<ApiOk<void>>());
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect(unauthorizedCalls, 0);
    });

    test('DELETE ignores a body on a 2xx answer', () async {
      setUpClient((_) async => _json('<html>x</html>', 200));

      expect(await client.delete('/api/proposals/abc'), isA<ApiOk<void>>());
    });

    test('DELETE 404 becomes not_found (second delete)', () async {
      setUpClient(
        (_) async =>
            _json('{"code":"not_found","message":"No proposal."}', 404),
      );

      final ApiResult<void> r = await client.delete('/api/proposals/abc');

      expect((r as ApiErr<void>).error.code, ApiErrorCodes.notFound);
      expect(unauthorizedCalls, 0);
    });

    test('DELETE 401 calls onUnauthorized once', () async {
      setUpClient((_) async => _json('', 401));

      final ApiResult<void> r = await client.delete('/api/proposals/abc');

      expect((r as ApiErr<void>).error.code, ApiErrorCodes.unauthorized);
      expect(unauthorizedCalls, 1);
    });

    test('PUT 401 calls onUnauthorized once', () async {
      setUpClient((_) async => _json('', 401));

      final ApiError e = errorOf(
        await client.put<String>('/api/proposals/abc', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.unauthorized);
      expect(unauthorizedCalls, 1);
    });

    test('DELETE 429 reads Retry-After', () async {
      setUpClient(
        (_) async => _json(
          '{"code":"rate_limited","message":"Slow down."}',
          429,
          h: <String, List<String>>{
            'retry-after': <String>['12'],
          },
        ),
      );

      final ApiResult<void> r = await client.delete('/api/proposals/abc');

      final ApiError e = (r as ApiErr<void>).error;
      expect(e.code, ApiErrorCodes.rateLimited);
      expect(e.retryAfterSeconds, 12);
    });

    test('DELETE with no network becomes network_error', () async {
      setUpClient(
        (RequestOptions o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );

      final ApiResult<void> r = await client.delete('/api/proposals/abc');

      expect((r as ApiErr<void>).error.code, ApiErrorCodes.network);
    });

    test('DELETE rejects a bad path', () {
      setUpClient((_) async => _json('', 204));

      expect(() => client.delete('https://evil.test/x'), throwsArgumentError);
    });
  });

  group('auth header', () {
    test('requiresAuth false: no header and the token is not read', () async {
      setUpClient((_) async => _json('{"name":"ok"}', 200));

      await client.post<String>(
        '/api/auth/signin',
        requiresAuth: false,
        parse: _parseName,
      );

      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(tokens.calls, 0);
    });

    test('no token: no header', () async {
      setUpClient((_) async => _json('{"name":"ok"}', 200), token: null);

      await client.get<String>('/api/stats', parse: _parseName);

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });
  });

  group('error mapping', () {
    test('400 validation keeps code, message and fields', () async {
      setUpClient(
        (_) async => _json(
          '{"code":"validation","message":"Fix it.",'
          '"fields":{"title":"Title is required."}}',
          400,
        ),
      );

      final ApiError e = errorOf(
        await client.post<String>('/api/proposals', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.validation);
      expect(e.message, 'Fix it.');
      expect(e.fields, <String, String>{'title': 'Title is required.'});
      expect(unauthorizedCalls, 0);
    });

    test('401 with an empty body on a protected call', () async {
      setUpClient((_) async => _json('', 401));

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.unauthorized);
      expect(unauthorizedCalls, 1);
    });

    test('401 invalid_credentials on sign in does not sign out', () async {
      setUpClient(
        (_) async => _json(
          '{"code":"invalid_credentials","message":"Wrong email or password."}',
          401,
        ),
      );

      final ApiError e = errorOf(
        await client.post<String>(
          '/api/auth/signin',
          requiresAuth: false,
          parse: _parseName,
        ),
      );

      expect(e.code, ApiErrorCodes.invalidCredentials);
      expect(unauthorizedCalls, 0);
    });

    test(
      'a throwing onUnauthorized callback does not break the call',
      () async {
        adapter = _FakeAdapter((_) async => _json('', 401));
        client = DioApiClient(
          baseUrl: 'https://example.test',
          tokenReader: _FakeTokenReader('t'),
          onUnauthorized: () => throw StateError('boom'),
          httpClientAdapter: adapter,
        );

        final ApiError e = errorOf(
          await client.get<String>('/api/stats', parse: _parseName),
        );

        expect(e.code, ApiErrorCodes.unauthorized);
      },
    );

    test('429 reads Retry-After', () async {
      setUpClient(
        (_) async => _json(
          '{"code":"rate_limited","message":"Slow down."}',
          429,
          h: <String, List<String>>{
            'retry-after': <String>['7'],
          },
        ),
      );

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.rateLimited);
      expect(e.retryAfterSeconds, 7);
      expect(e.message, 'Slow down.');
    });

    test('429 with a bad Retry-After and no body', () async {
      setUpClient(
        (_) async => _json(
          '',
          429,
          h: <String, List<String>>{
            'retry-after': <String>['Wed, 21 Oct 2026 07:28:00 GMT'],
          },
        ),
      );

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.rateLimited);
      expect(e.retryAfterSeconds, isNull);
      expect(e.message, isNotEmpty);
    });

    test('429 Retry-After is capped', () async {
      setUpClient(
        (_) async => _json(
          '',
          429,
          h: <String, List<String>>{
            'retry-after': <String>['999999'],
          },
        ),
      );

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.retryAfterSeconds, 3600);
    });

    test('500 with plain text becomes server_error', () async {
      setUpClient(
        (_) async => ResponseBody.fromString(
          'Internal Server Error',
          500,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/plain'],
          },
        ),
      );

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.serverError);
    });

    test('413 with an empty body becomes bad_request', () async {
      setUpClient((_) async => _json('', 413));

      final ApiError e = errorOf(
        await client.post<String>('/api/proposals', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.badRequest);
    });

    test('an error body without a code uses the status fallback', () async {
      setUpClient((_) async => _json('{"title":"Not Found"}', 404));

      final ApiError e = errorOf(
        await client.get<String>('/api/proposals/x', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.notFound);
    });

    test('a redirect is not followed and is an error', () async {
      setUpClient((_) async => _json('', 302));

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.unknown);
      expect(adapter.requests, hasLength(1));
    });
  });

  group('transport errors', () {
    for (final DioExceptionType type in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.unknown,
    ]) {
      test('$type becomes network_error', () async {
        setUpClient(
          (RequestOptions o) async =>
              throw DioException(requestOptions: o, type: type),
        );

        final ApiError e = errorOf(
          await client.get<String>('/api/stats', parse: _parseName),
        );

        expect(e.code, ApiErrorCodes.network);
        expect(unauthorizedCalls, 0);
      });
    }
  });

  group('bad success bodies', () {
    test('invalid JSON on 200 becomes bad_response', () async {
      setUpClient((_) async => _json('<html>oops</html>', 200));

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.badResponse);
    });

    test('a JSON array on 200 becomes bad_response', () async {
      setUpClient((_) async => _json('[1,2,3]', 200));

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.badResponse);
    });

    test('a wrong shape (parser throws) becomes bad_response', () async {
      setUpClient((_) async => _json('{"name":42}', 200));

      final ApiError e = errorOf(
        await client.get<String>('/api/stats', parse: _parseName),
      );

      expect(e.code, ApiErrorCodes.badResponse);
    });
  });

  group('path guard', () {
    setUp(() => setUpClient((_) async => _json('{"name":"ok"}', 200)));

    for (final String bad in <String>[
      'https://evil.test/steal',
      '//evil.test/steal',
      'api/stats',
      r'\evil',
      '/redirect?u=http://evil.test',
    ]) {
      test('rejects "$bad"', () {
        expect(
          () => client.get<String>(bad, parse: _parseName),
          throwsArgumentError,
        );
        expect(adapter.requests, isEmpty);
      });
    }
  });
}
