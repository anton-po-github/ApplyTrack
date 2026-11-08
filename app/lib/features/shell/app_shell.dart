import 'package:apply_track/core/layout/window_size.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _ShellTab {
  const new({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The order MUST match the branches of the `StatefulShellRoute`.
const List<_ShellTab> _tabs = <_ShellTab>[
  _ShellTab(
    label: 'Proposals',
    icon: Icons.list_alt_outlined,
    selectedIcon: Icons.list_alt,
  ),
  _ShellTab(
    label: 'Stats',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
];

/// The frame of the signed-in app: an AppBar (user name, sign out) and two
/// tabs. A bottom bar on a phone, a side rail on a wider window.
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = WindowSize.fromWidth(MediaQuery.sizeOf(context).width);
    final index = navigationShell.currentIndex;

    // Tapping the open tab goes back to the first page of that tab.
    void select(int next) =>
        navigationShell.goBranch(next, initialLocation: next == index);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ApplyTrack'),
        actions: const <Widget>[_UserActions()],
      ),
      body: switch (size) {
        WindowSize.compact => navigationShell,
        WindowSize.medium || WindowSize.expanded => Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              extended: size == WindowSize.expanded,
              labelType: size == WindowSize.expanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final _ShellTab tab in _tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      },
      bottomNavigationBar: size == WindowSize.compact
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: <Widget>[
                for (final _ShellTab tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _UserActions extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final busy = ref.watch(authBusyProvider);

    if (auth is! AuthSignedIn) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                auth.user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: busy
              ? null
              : () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
