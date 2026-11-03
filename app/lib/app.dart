import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phase2_widgets/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Phase 2 Widgets',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
