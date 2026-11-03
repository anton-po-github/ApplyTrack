import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apply_track/app.dart';
import 'package:apply_track/features/counter/counter_screen.dart';
import 'package:apply_track/features/home/home_screen.dart';
import 'package:apply_track/router/app_router.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    String location = AppRoutes.home,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: App(router: createAppRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the home screen', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('tap on Counter opens the counter, back returns home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Counter'));
    await tester.pumpAndSettle();
    expect(find.byType(CounterScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('unknown path shows the not found screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, location: '/nope');

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('No page for /nope'), findsOneWidget);
  });
}
