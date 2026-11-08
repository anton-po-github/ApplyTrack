import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:apply_track/features/auth/ui/startup_screen.dart';
import 'package:apply_track/features/home/not_found_screen.dart';
import 'package:apply_track/features/proposals/domain/proposal_id.dart';
import 'package:apply_track/features/proposals/ui/proposal_detail_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_form_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_list_screen.dart';
import 'package:apply_track/features/proposals/ui/stats_screen.dart';
import 'package:apply_track/features/shell/app_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
  final onPublic = location == AppRoutes.login || location == AppRoutes.signup;
  final onStartup = location == AppRoutes.startup;

  return switch (auth) {
    AuthUnknown() || AuthUnavailable() => onStartup ? null : AppRoutes.startup,
    AuthSignedOut() => onPublic ? null : AppRoutes.login,
    AuthSignedIn() => onPublic || onStartup ? AppRoutes.home : null,
  };
}

/// A page for one proposal. A bad id never reaches the screen.
Widget _proposalPage(GoRouterState state, Widget Function(String id) build) {
  final id = state.pathParameters['id'];
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
    redirect: (context, state) => authRedirect(authState(), state.uri.path),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // The order of the branches MUST match the tabs in `AppShell`.
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const ProposalListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
        ],
      ),
      // `new` MUST come before `:id`, or "new" would be read as an id.
      GoRoute(
        path: AppRoutes.proposalNew,
        builder: (context, state) => const ProposalFormScreen(),
      ),
      GoRoute(
        path: '/proposals/:id',
        builder: (context, state) => _proposalPage(
          state,
          (id) =>
              ProposalDetailScreen(key: ValueKey<String>(id), proposalId: id),
        ),
      ),
      GoRoute(
        path: '/proposals/:id/edit',
        builder: (context, state) =>
            _proposalPage(state, (id) => ProposalFormScreen(proposalId: id)),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}

/// Tests override this to start on another page.
final Provider<String> initialLocationProvider = Provider<String>(
  (ref) => AppRoutes.home,
);

/// Reading the auth controller here also starts the session check.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) => refresh.value++,
  );

  final router = createAppRouter(
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
