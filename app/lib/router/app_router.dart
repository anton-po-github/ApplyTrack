import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:apply_track/features/auth/ui/startup_screen.dart';
import 'package:apply_track/features/counter/counter_screen.dart';
import 'package:apply_track/features/home/home_screen.dart';
import 'package:apply_track/features/home/not_found_screen.dart';
import 'package:apply_track/features/layout_demo/widgets/layout_demo_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String counter = '/counter';
  static const String layout = '/layout';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String startup = '/startup';
}

/// The guard (like a CanActivate in Angular). A pure function, so it is
/// easy to test. Returns null when the user may stay where they are.
String? authRedirect(AuthState auth, String location) {
  final bool onPublic =
      location == AppRoutes.login || location == AppRoutes.signup;
  final bool onStartup = location == AppRoutes.startup;

  return switch (auth) {
    AuthUnknown() || AuthUnavailable() => onStartup ? null : AppRoutes.startup,
    AuthSignedOut() => onPublic ? null : AppRoutes.login,
    AuthSignedIn() => onPublic || onStartup ? AppRoutes.home : null,
  };
}

GoRouter createAppRouter({
  required AuthState Function() authState,
  required Listenable refreshListenable,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) =>
        authRedirect(authState(), state.uri.path),
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
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (BuildContext context, GoRouterState state) =>
            const StartupScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}

/// Tests override this to start on another page.
final Provider<String> initialLocationProvider = Provider<String>(
  (Ref ref) => AppRoutes.home,
);

/// Reading the auth controller here also starts the session check.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(
    authControllerProvider,
    (AuthState? previous, AuthState next) => refresh.value++,
  );

  final GoRouter router = createAppRouter(
    authState: () => ref.read(authControllerProvider),
    refreshListenable: refresh,
    initialLocation: ref.read(initialLocationProvider),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
