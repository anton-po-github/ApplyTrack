import 'package:apply_track/features/counter/counter.dart';
import 'package:apply_track/features/counter/counter_providers.dart';
import 'package:apply_track/features/counter/counter_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_counter_store.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    FakeCounterStore? store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (store != null) counterStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: CounterScreen()),
      ),
    );
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
  }

  testWidgets('tap adds 1 and Reset goes back to 0', (tester) async {
    await pumpScreen(tester);
    expect(find.text('0'), findsOneWidget);

    await tapAdd(tester);
    await tapAdd(tester);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('button is disabled at max', (tester) async {
    await pumpScreen(tester);

    for (var i = 0; i < 5; i++) {
      await tapAdd(tester);
    }

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(find.text('5'), findsOneWidget);
    expect(fab.onPressed, isNull);
  });

  testWidgets('shows the stored value and saves after a tap', (tester) async {
    final store = FakeCounterStore(const Counter(value: 4));
    await pumpScreen(tester, store: store);
    expect(find.text('4'), findsOneWidget);

    await tapAdd(tester);

    expect(find.text('5'), findsOneWidget);
    expect(store.saved.single.value, 5);
  });
}
