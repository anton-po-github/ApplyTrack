import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';

/// Shown while the app checks the saved session (Unknown),
/// or when the server cannot be reached (Unavailable).
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final bool busy = ref.watch(authBusyProvider);

    return Scaffold(
      body: Center(
        child: switch (auth) {
          AuthUnavailable() => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: <Widget>[
                const Icon(Icons.cloud_off_outlined, size: 48),
                const Text(
                  'Cannot reach the server.\nCheck your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).restore(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          _ => const CircularProgressIndicator(),
        },
      ),
    );
  }
}
