import 'dart:convert';
import 'dart:math' as math;

import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/api/token_reader.dart';
import 'package:dio/dio.dart';

typedef UnauthorizedCallback = void Function();

const String _requiresAuthKey = 'requiresAuth';
const int _maxRetryAfterSeconds = 3600;

/// The ONLY file in the app that knows `dio`.
final class DioApiClient implements ApiClient {
  new({
    required String baseUrl,
    required TokenReader tokenReader,
    required this._onUnauthorized,
    HttpClientAdapter? httpClientAdapter,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration sendTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeout,
           sendTimeout: sendTimeout,
           receiveTimeout: receiveTimeout,
           // Plain text: we decode JSON ourselves, so a bad or empty body
           // can never crash the app.
           responseType: ResponseType.plain,
           // Every status comes back as a normal response. We map it below.
           validateStatus: (_) => true,
           // Never follow redirects: the Bearer token must not leave our host.
           followRedirects: false,
           contentType: Headers.jsonContentType,
           headers: <String, Object?>{'Accept': Headers.jsonContentType},
         ),
       ) {
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
    _dio.interceptors.add(_BearerInterceptor(tokenReader));
  }

  final Dio _dio;
  final UnauthorizedCallback _onUnauthorized;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? query,
    bool requiresAuth = true,
  }) => _send<T>(
    'GET',
    path,
    parse: parse,
    query: query,
    requiresAuth: requiresAuth,
  );

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) => _send<T>(
    'POST',
    path,
    parse: parse,
    body: body,
    requiresAuth: requiresAuth,
  );

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) => _send<T>(
    'PUT',
    path,
    parse: parse,
    body: body,
    requiresAuth: requiresAuth,
  );

  @override
  Future<ApiResult<void>> delete(
    String path, {
    bool requiresAuth = true,
  }) async {
    final raw = await _execute('DELETE', path, requiresAuth: requiresAuth);
    return switch (raw) {
      ApiOk<Object?>() => const ApiOk<void>(null),
      ApiErr<Object?>(:final ApiError error) => ApiErr<void>(error),
    };
  }

  Future<ApiResult<T>> _send<T>(
    String method,
    String path, {
    required JsonParser<T> parse,
    required bool requiresAuth,
    Map<String, Object?>? query,
    Map<String, Object?>? body,
  }) async {
    final raw = await _execute(
      method,
      path,
      requiresAuth: requiresAuth,
      query: query,
      body: body,
    );
    switch (raw) {
      case ApiErr<Object?>(:final ApiError error):
        return ApiErr<T>(error);
      case ApiOk<Object?>(:final Object? value):
        if (value is! Map<String, Object?>) {
          return ApiErr<T>(const ApiError.badResponse());
        }
        try {
          return ApiOk<T>(parse(value));
        } on FormatException {
          return ApiErr<T>(const ApiError.badResponse());
          // A wrong JSON shape makes parse() throw a TypeError. Not a crash.
          // ignore: avoid_catching_errors
        } on TypeError {
          return ApiErr<T>(const ApiError.badResponse());
        }
    }
  }

  /// Sends the request and maps every failure to [ApiErr].
  /// On 2xx it returns the decoded JSON (null when the body is empty).
  Future<ApiResult<Object?>> _execute(
    String method,
    String path, {
    required bool requiresAuth,
    Map<String, Object?>? query,
    Map<String, Object?>? body,
  }) async {
    _checkPath(path);

    final Response<String> response;
    try {
      response = await _dio.request<String>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        options: Options(
          method: method,
          extra: <String, Object?>{_requiresAuthKey: requiresAuth},
        ),
      );
    } on DioException catch (e) {
      return ApiErr<Object?>(_mapTransportError(e));
    }

    final status = response.statusCode ?? 0;
    final json = _decode(response.data);

    if (status >= 200 && status < 300) return ApiOk<Object?>(json);

    final error = _mapErrorResponse(status, response.headers, json);
    if (status == 401 && requiresAuth) _notifyUnauthorized();
    return ApiErr<Object?>(error);
  }

  void _notifyUnauthorized() {
    try {
      _onUnauthorized();
    } on Object {
      // A broken callback must not break the "never throws" promise.
    }
  }

  /// A path with a host would replace our base URL and the token could leak.
  static void _checkPath(String path) {
    final bad =
        !path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://') ||
        path.contains(r'\');
    if (bad) {
      throw ArgumentError.value(
        path,
        'path',
        'Must be a relative path that starts with one "/"',
      );
    }
  }

  static Map<String, String>? _cleanQuery(Map<String, Object?>? query) {
    if (query == null) return null;
    final result = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null) result[entry.key] = value.toString();
    }
    return result.isEmpty ? null : result;
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static ApiError _mapTransportError(DioException e) => switch (e.type) {
    DioExceptionType.cancel => const ApiError(
      code: ApiErrorCodes.unknown,
      message: 'The request was cancelled.',
    ),
    // Timeouts, no network, bad certificate and unknown transport errors.
    _ => const ApiError.network(),
  };

  static ApiError _mapErrorResponse(int status, Headers headers, Object? json) {
    if (status == 429) {
      return ApiError(
        code: ApiErrorCodes.rateLimited,
        message:
            _bodyMessage(json) ?? 'Too many requests. Please wait a little.',
        retryAfterSeconds: _parseRetryAfter(headers['retry-after']),
      );
    }
    if (json is Map<String, Object?>) {
      final parsed = ApiError.fromJson(json);
      if (parsed.code != ApiErrorCodes.unknown) return parsed;
    }
    return _fallbackError(status);
  }

  static ApiError _fallbackError(int status) => switch (status) {
    401 => const ApiError.unauthorized(),
    400 || 413 || 415 => const ApiError(
      code: ApiErrorCodes.badRequest,
      message: 'The request was not accepted.',
    ),
    404 => const ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
    >= 500 => const ApiError(
      code: ApiErrorCodes.serverError,
      message: 'Server error. Please try again later.',
    ),
    _ => const ApiError(
      code: ApiErrorCodes.unknown,
      message: 'Something went wrong.',
    ),
  };

  static String? _bodyMessage(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final message = json['message'];
    return message is String && message.isNotEmpty ? message : null;
  }

  /// Only whole seconds are accepted. Other formats become null.
  static int? _parseRetryAfter(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    final seconds = int.tryParse(values.first.trim());
    if (seconds == null || seconds < 0) return null;
    return math.min(seconds, _maxRetryAfterSeconds);
  }
}

/// Adds `Authorization: Bearer <token>` only when the call needs auth.
final class _BearerInterceptor extends Interceptor {
  new(this._tokenReader);

  final TokenReader _tokenReader;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_requiresAuthKey] == true) {
      String? token;
      try {
        token = await _tokenReader.readToken();
      } on Exception {
        token = null; // Broken storage = no session.
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
