import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:apply_track/features/auth/ui/startup_screen.dart';
import 'package:apply_track/features/home/not_found_screen.dart';
import 'package:apply_track/features/proposals/domain/proposal_id.dart';
import 'package:apply_track/features/shell/app_shell.dart';
import 'package:apply_track/features/shell/placeholder_screens.dart';

abstract final class AppRoutes {
  /// The proposal list (first tab).
  static const String home = '/';
  static const String stats = '/stats';
  static const String proposalNew = '/proposals/new';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String startup = '/startup';

  // Not routed any more. Step 12 deletes them with their screens.
  static const String counter = '/counter';
  static const String layout = '/layout';

  /// The id must be a GUID. Anything else goes to the not found screen.
  static String proposal(String id) => '/proposals/${Uri.encodeComponent(id)}';

  static String proposalEdit(String id) => '${proposal(id)}/edit';
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

/// A page for one proposal. A bad id never reaches the screen.
Widget _proposalPage(GoRouterState state, Widget Function(String id) build) {
  final String? id = state.pathParameters['id'];
  if (id == null || !ProposalId.isValid(id)) {
    return NotFoundScreen(location: state.uri.toString());
  }
  return build(id);
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
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        // The order of the branches MUST match the tabs in `AppShell`.
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const PlaceholderBody(text: 'Proposal list - coming soon'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.stats,
                builder: (BuildContext context, GoRouterState state) =>
                    const PlaceholderBody(text: 'Stats - coming soon'),
              ),
            ],
          ),
        ],
      ),
      // `new` MUST come before `:id`, or "new" would be read as an id.
      GoRoute(
        path: AppRoutes.proposalNew,
        builder: (BuildContext context, GoRouterState state) =>
            const PlaceholderPage(
              title: 'New proposal',
              text: 'New proposal form - coming soon',
            ),
      ),
      GoRoute(
        path: '/proposals/:id',
        builder: (BuildContext context, GoRouterState state) => _proposalPage(
          state,
          (String id) => const PlaceholderPage(
            title: 'Proposal',
            text: 'Proposal details - coming soon',
          ),
        ),
      ),
      GoRoute(
        path: '/proposals/:id/edit',
        builder: (BuildContext context, GoRouterState state) => _proposalPage(
          state,
          (String id) => const PlaceholderPage(
            title: 'Edit proposal',
            text: 'Edit proposal form - coming soon',
          ),
        ),
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
