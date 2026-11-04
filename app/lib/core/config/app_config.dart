final class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.googleServerClientId,
  });

  static const String defaultApiBaseUrl =
      'https://apply-track-eu.azurewebsites.net';

  /// Values come from --dart-define (see config/dev.json).
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  );

  final String apiBaseUrl;
  final String googleServerClientId;

  bool get hasGoogleClientId => googleServerClientId.isNotEmpty;
}
