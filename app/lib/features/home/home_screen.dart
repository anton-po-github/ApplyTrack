import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/core/layout/window_size.dart';
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

const List<HomeDestination> _destinations = <HomeDestination>[
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
  HomeDestination(
    title: 'Sign up',
    subtitle: 'Form + validation',
    icon: Icons.person_add_alt_outlined,
    route: AppRoutes.signup,
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _tileHeight = 88;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ApplyTrack')),
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
              itemCount: _destinations.length,
              itemBuilder: (BuildContext context, int index) =>
                  _DestinationCard(destination: _destinations[index]),
            );
          },
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
