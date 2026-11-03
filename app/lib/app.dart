import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/theme/app_theme.dart';

import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:5000',
);

Future<void> pingServer() async {
  try {
    final response = await http
        .get(Uri.parse('$apiUrl/api/ping'))
        .timeout(const Duration(seconds: 5));
    debugPrint('Ping: ${response.statusCode} ${response.body}');
  } catch (e) {
    debugPrint('Ping failed: $e');
  }
}

class App extends StatelessWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ApplyTrack',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
