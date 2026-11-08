import 'package:apply_track/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default API URL is https and has no trailing slash', () {
    expect(AppConfig.defaultApiBaseUrl, startsWith('https://'));
    expect(AppConfig.defaultApiBaseUrl, isNot(endsWith('/')));
  });

  test('hasGoogleClientId is false when the id is empty', () {
    const config = AppConfig(
      apiBaseUrl: 'https://example.com',
      googleServerClientId: '',
    );
    expect(config.hasGoogleClientId, isFalse);
  });

  test('hasGoogleClientId is true when the id is set', () {
    const config = AppConfig(
      apiBaseUrl: 'https://example.com',
      googleServerClientId: 'abc.apps.googleusercontent.com',
    );
    expect(config.hasGoogleClientId, isTrue);
  });
}
