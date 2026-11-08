import 'package:apply_track/core/api/api_error.dart';

/// Like a TypeScript union: { ok: true, value } | { ok: false, error }.
sealed class ApiResult<T> {
  const new();
}

final class ApiOk<T> extends ApiResult<T> {
  const new(this.value);

  final T value;
}

final class ApiErr<T> extends ApiResult<T> {
  const new(this.error);

  final ApiError error;
}
