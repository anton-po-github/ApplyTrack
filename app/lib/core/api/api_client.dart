import 'package:apply_track/core/api/api_result.dart';

/// Turns a JSON object from the server into a model.
/// It may throw [FormatException] on a wrong shape.
typedef JsonParser<T> = T Function(Map<String, Object?> json);

/// The only HTTP door for the app. It never throws on API errors.
/// Every failure comes back as [ApiErr].
abstract interface class ApiClient {
  /// [path] must be relative and start with one `/` (for example `/api/stats`).
  /// Null values in [query] are removed.
  Future<ApiResult<T>> get<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? query,
    bool requiresAuth = true,
  });

  /// Sends [body] as JSON. Use `requiresAuth: false` for sign in and sign up.
  Future<ApiResult<T>> post<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  });

  /// Sends [body] as JSON and replaces a resource (full replace).
  Future<ApiResult<T>> put<T>(
    String path, {
    required JsonParser<T> parse,
    Map<String, Object?>? body,
    bool requiresAuth = true,
  });

  /// Success is any 2xx answer. The server sends `204` with no body, and
  /// the body is ignored.
  Future<ApiResult<void>> delete(String path, {bool requiresAuth = true});
}
