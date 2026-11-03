import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/features/counter/counter_screen.dart';
import 'package:apply_track/features/home/home_screen.dart';
import 'package:apply_track/features/home/not_found_screen.dart';
import 'package:apply_track/features/layout_demo/widgets/layout_demo_screen.dart';
import 'package:apply_track/features/signup/signup_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String counter = '/counter';
  static const String layout = '/layout';
  static const String signup = '/signup';
}

GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.counter,
        builder: (BuildContext context, GoRouterState state) =>
            const CounterScreen(),
      ),
      GoRoute(
        path: AppRoutes.layout,
        builder: (BuildContext context, GoRouterState state) =>
            const LayoutDemoScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}
