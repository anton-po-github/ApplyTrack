import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/core/layout/window_size.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/router/app_router.dart';

final class HomeDestination {
  const HomeDestination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

const List<HomeDestination> homeDestinations = <HomeDestination>[
  HomeDestination(
    title: 'Counter',
    subtitle: 'Riverpod state',
    icon: Icons.add_circle_outline,
    route: AppRoutes.counter,
  ),
  HomeDestination(
    title: 'Layout demo',
    subtitle: 'Row, Column, Stack',
    icon: Icons.view_quilt_outlined,
    route: AppRoutes.layout,
  ),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.destinations = homeDestinations});

  static const double _tileHeight = 88;

  final List<HomeDestination> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final bool busy = ref.watch(authBusyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ApplyTrack'),
        actions: <Widget>[
          if (auth case AuthSignedIn(:final user)) ...<Widget>[
            _UserName(user.displayName),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: busy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ],
      ),
      body: MaxContentWidth(
        maxWidth: 1000,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = switch (WindowSize.fromWidth(
              constraints.maxWidth,
            )) {
              WindowSize.compact => 1,
              WindowSize.medium => 2,
              WindowSize.expanded => 3,
            };

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: _tileHeight,
              ),
              itemCount: destinations.length,
              itemBuilder: (BuildContext context, int index) =>
                  _DestinationCard(destination: destinations[index]),
            );
          },
        ),
      ),
    );
  }
}

class _UserName extends StatelessWidget {
  const _UserName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination});

  final HomeDestination destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(destination.icon),
        title: Text(destination.title),
        subtitle: Text(destination.subtitle),
        onTap: () => context.push(destination.route),
      ),
    );
  }
}
