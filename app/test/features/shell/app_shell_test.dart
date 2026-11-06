import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_list_screen.dart';
import 'package:apply_track/features/proposals/ui/stats_screen.dart';
import 'package:apply_track/features/shell/app_shell.dart';
import 'package:apply_track/router/app_router.dart';

import '../../support/app_test_helpers.dart';
import '../../support/auth_test_helpers.dart';

void main() {
  String currentPath(WidgetTester tester) => routerOf(
    tester,
    find.byType(AppShell),
  ).routerDelegate.currentConfiguration.uri.path;

  group('navigation by window size', () {
    testWidgets('399 wide: bottom bar, no rail', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 399);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('599 wide: still a bottom bar', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 599);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('600 wide: side rail with labels, no bottom bar', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo(), width: 600);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
    });

    testWidgets('900 wide: extended side rail', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 900);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
    });

    testWidgets('bottom bar shows both tab names', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      expect(find.text('Proposals'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('side rail shows both tab names', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 900);

      expect(find.text('Proposals'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });
  });

  group('tab switching (bottom bar)', () {
    testWidgets('opens on the Proposals tab', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      expect(find.byType(ProposalListScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(currentPath(tester), AppRoutes.home);
    });

    testWidgets('Stats opens the stats tab and Proposals comes back', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);
      expect(find.byType(ProposalListScreen), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(currentPath(tester), AppRoutes.stats);

      await tester.tap(find.text('Proposals'));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalListScreen), findsOneWidget);
      expect(currentPath(tester), AppRoutes.home);
    });

    testWidgets('a link to /stats opens the second tab', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      await goTo(tester, AppRoutes.stats);

      expect(find.byType(StatsScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });
  });

  group('tab switching (side rail)', () {
    testWidgets('switches tabs with the rail', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 900);

      expect(find.byType(ProposalListScreen), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );

      await tester.tap(find.text('Proposals'));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalListScreen), findsOneWidget);
    });
  });

  group('app bar', () {
    testWidgets('shows the user name and the sign out button', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      expect(find.text('Anton'), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
    });

    testWidgets('sign out clears the session and shows login', (tester) async {
      final FakeAuthRepository repo = signedInRepo();
      await pumpApp(tester, repo, width: 900);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(repo.signOutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('the app bar stays on the Stats tab', (tester) async {
      await pumpApp(tester, signedInRepo(), width: 400);

      await goTo(tester, AppRoutes.stats);

      expect(find.text('Anton'), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
    });
  });
}
