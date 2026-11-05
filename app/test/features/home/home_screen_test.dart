import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/home/home_screen.dart';

import '../../support/auth_test_helpers.dart';

const List<HomeDestination> _three = <HomeDestination>[
  HomeDestination(title: 'A', subtitle: 'a', icon: Icons.home, route: '/a'),
  HomeDestination(title: 'B', subtitle: 'b', icon: Icons.home, route: '/b'),
  HomeDestination(title: 'C', subtitle: 'c', icon: Icons.home, route: '/c'),
];

void main() {
  Future<FakeAuthRepository> pumpHome(
    WidgetTester tester, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeAuthRepository repo = FakeAuthRepository(session: validSession());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomeScreen(destinations: _three)),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<List<Offset>> cardPositions(WidgetTester tester, double width) async {
    await pumpHome(tester, width: width);
    return <Offset>[
      for (int i = 0; i < 3; i++) tester.getTopLeft(find.byType(Card).at(i)),
    ];
  }

  testWidgets('400 wide: one column', (WidgetTester tester) async {
    final List<Offset> p = await cardPositions(tester, 400);

    expect(p[1].dx, closeTo(p[0].dx, 0.01));
    expect(p[1].dy, greaterThan(p[0].dy));
  });

  testWidgets('700 wide: two columns', (WidgetTester tester) async {
    final List<Offset> p = await cardPositions(tester, 700);

    expect(p[1].dy, closeTo(p[0].dy, 0.01));
    expect(p[1].dx, greaterThan(p[0].dx));
    expect(p[2].dy, greaterThan(p[0].dy));
  });

  testWidgets('900 wide: three columns in one row', (
    WidgetTester tester,
  ) async {
    final List<Offset> p = await cardPositions(tester, 900);

    expect(p[1].dy, closeTo(p[0].dy, 0.01));
    expect(p[2].dy, closeTo(p[0].dy, 0.01));
  });

  testWidgets('1400 wide: content is centered, max 1000', (
    WidgetTester tester,
  ) async {
    final List<Offset> p = await cardPositions(tester, 1400);

    // (1400 - 1000) / 2 = 200, plus 16 padding
    expect(p[0].dx, closeTo(216, 0.5));
  });

  testWidgets('shows the display name', (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.text('Anton'), findsOneWidget);
  });

  testWidgets('Sign out clears the session', (WidgetTester tester) async {
    final FakeAuthRepository repo = await pumpHome(tester);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(repo.signOutCalls, 1);
    expect(find.text('Anton'), findsNothing);
    expect(find.byTooltip('Sign out'), findsNothing);
  });
}
