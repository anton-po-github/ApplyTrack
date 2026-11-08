import 'package:apply_track/app.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/shell/app_shell.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_test_helpers.dart';
import 'fake_proposals_api.dart';
import 'fake_stats_api.dart';

/// A valid proposal id for route tests.
const String routeTestId = '0190a1b2-0000-7000-8000-000000000001';

/// Pumps the whole app (router, guard, shell) with a fake auth repository.
/// Pass [width] to test another window size (the default test window is 800).
Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  String location = AppRoutes.home,
  double? width,
  FakeProposalsApi? proposalsApi,
  FakeStatsApi? statsApi,
}) async {
  if (width != null) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        proposalsApiProvider.overrideWithValue(
          proposalsApi ?? FakeProposalsApi(),
        ),
        statsApiProvider.overrideWithValue(statsApi ?? FakeStatsApi()),
        initialLocationProvider.overrideWithValue(location),
      ],
      child: const AppRoot(),
    ),
  );
  await tester.pumpAndSettle();
}

FakeAuthRepository signedInRepo() =>
    FakeAuthRepository(session: validSession());

/// The router of a running app. [anchor] is any widget inside the app.
GoRouter routerOf(WidgetTester tester, Finder anchor) =>
    ProviderScope.containerOf(tester.element(anchor)).read(appRouterProvider);

/// Goes to [path] in a running app (the shell must be on screen).
/// An initial location does not work for this: at start the guard sends
/// the user to the startup page, then to the home page.
Future<void> goTo(WidgetTester tester, String path) async {
  routerOf(tester, find.byType(AppShell)).go(path);
  await tester.pumpAndSettle();
}
