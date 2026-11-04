import 'package:apply_track/core/api/api_error.dart';

/// Like a TypeScript union: { ok: true, value } | { ok: false, error }.
sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiOk<T> extends ApiResult<T> {
  const ApiOk(this.value);

  final T value;
}

final class ApiErr<T> extends ApiResult<T> {
  const ApiErr(this.error);

  final ApiError error;
}
