import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ApiError limited(int? seconds) => ApiError(
    code: ApiErrorCodes.rateLimited,
    message: 'raw server text',
    retryAfterSeconds: seconds,
  );

  test('rate limit shows the seconds', () {
    expect(
      apiErrorMessage(limited(30)),
      'Too many requests. Try again in 30 seconds.',
    );
  });

  test('rate limit with one second uses the singular', () {
    expect(
      apiErrorMessage(limited(1)),
      'Too many requests. Try again in 1 second.',
    );
  });

  test('rate limit without a usable time has a general text', () {
    const general = 'Too many requests. Please wait a moment and try again.';
    expect(apiErrorMessage(limited(null)), general);
    expect(apiErrorMessage(limited(0)), general);
  });

  test('server error has a calm text', () {
    expect(
      apiErrorMessage(
        const ApiError(code: ApiErrorCodes.serverError, message: 'boom'),
      ),
      'The server has a problem. Try again in a moment.',
    );
  });

  test('other errors use their own message', () {
    expect(
      apiErrorMessage(const ApiError.network()),
      'No connection. Check your internet and try again.',
    );
    expect(
      apiErrorMessage(
        const ApiError(code: ApiErrorCodes.notFound, message: 'Gone.'),
      ),
      'Gone.',
    );
  });
}
