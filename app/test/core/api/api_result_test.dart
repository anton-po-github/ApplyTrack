import 'package:flutter_test/flutter_test.dart';
import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';

String describe(ApiResult<int> result) => switch (result) {
  ApiOk<int>(:final int value) => 'ok $value',
  ApiErr<int>(:final ApiError error) => 'err ${error.code}',
};

void main() {
  test('ok carries the value', () {
    expect(describe(const ApiOk<int>(7)), 'ok 7');
  });

  test('err carries the error', () {
    expect(
      describe(const ApiErr<int>(ApiError.network())),
      'err network_error',
    );
  });
}
