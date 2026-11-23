import 'package:apply_track/features/proposals/state/follow_up_reminder_cleaner.dart';
import 'package:apply_track/features/proposals/state/proposal_cache_cleaner.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:apply_track/router/notification_tap_router.dart';
import 'package:apply_track/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class App extends StatelessWidget {
  const new({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ApplyTrack',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}

/// Gets the router (with the auth guard) from Riverpod.
class AppRoot extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the saved proposal list clean when a user leaves.
    ref.watch(proposalCacheCleanerProvider);
    // Removes the phone reminders when a user leaves.
    ref.watch(followUpReminderCleanerProvider);
    // Opens a proposal when the user taps its reminder.
    ref.watch(notificationTapRouterProvider);
    return App(router: ref.watch(appRouterProvider));
  }
}
