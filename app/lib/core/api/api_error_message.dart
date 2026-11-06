import 'package:apply_track/core/api/api_error.dart';

/// The text the user sees for an [ApiError].
/// Step 12 adds the other cases in this one place.
String apiErrorMessage(ApiError error) {
  switch (error.code) {
    case ApiErrorCodes.rateLimited:
      final int? seconds = error.retryAfterSeconds;
      if (seconds == null || seconds <= 0) {
        return 'Too many requests. Please wait a moment and try again.';
      }
      final String unit = seconds == 1 ? 'second' : 'seconds';
      return 'Too many requests. Try again in $seconds $unit.';
    case ApiErrorCodes.serverError:
      return 'The server has a problem. Try again in a moment.';
    default:
      return error.message;
  }
}
