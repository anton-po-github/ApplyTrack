final class AppConfig {
  const new({required this.apiBaseUrl, required this.googleServerClientId});

  /// Values come from --dart-define (see config/dev.json).
  factory fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  );

  static const String defaultApiBaseUrl =
      'https://apply-track-eu.azurewebsites.net';

  final String apiBaseUrl;
  final String googleServerClientId;

  bool get hasGoogleClientId => googleServerClientId.isNotEmpty;
}
