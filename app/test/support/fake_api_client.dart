import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';

/// One call that reached the fake client.
final class RecordedCall {
  const new({
    required this.method,
    required this.path,
    required this.requiresAuth,
    this.query,
    this.body,
  });

  final String method;
  final String path;
  final bool requiresAuth;
  final Map<String, Object?>? query;
  final Map<String, Object?>? body;
}

/// A fake [ApiClient]. It records every call and answers with [json],
/// or with [error] when [error] is set.
final class FakeApiClient implements ApiClient {
  final List<RecordedCall> calls = <RecordedCall>[];

  Map<String, Object?> json = <String, Object?>{};
  ApiError? error;

  RecordedCall get last => calls.last;

  ApiResult<T> _answer<T>(JsonParser<T> parse) {
    final failure = error;
    if (failure != null) return ApiErr<T>(failure);
    return ApiOk<T>(parse(json));
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? query,
    bool requiresAuth = true,
  }) async {
    calls.add(
      RecordedCall(
        method: 'GET',
        path: path,
        query: query,
        requiresAuth: requiresAuth,
      ),
    );
    return _answer<T>(parse);
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) async {
    calls.add(
      RecordedCall(
        method: 'POST',
        path: path,
        body: body,
        requiresAuth: requiresAuth,
      ),
    );
    return _answer<T>(parse);
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  }) async {
    calls.add(
      RecordedCall(
        method: 'PUT',
        path: path,
        body: body,
        requiresAuth: requiresAuth,
      ),
    );
    return _answer<T>(parse);
  }

  @override
  Future<ApiResult<void>> delete(
    String path, {
    bool requiresAuth = true,
  }) async {
    calls.add(
      RecordedCall(method: 'DELETE', path: path, requiresAuth: requiresAuth),
    );
    final failure = error;
    if (failure != null) return ApiErr<void>(failure);
    return const ApiOk<void>(null);
  }
}
