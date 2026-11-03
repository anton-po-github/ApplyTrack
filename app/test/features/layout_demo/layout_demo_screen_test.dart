import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/features/layout_demo/widgets/demo_box.dart';
import 'package:apply_track/features/layout_demo/widgets/layout_demo_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutDemoScreen()));
  }

  testWidgets('shows all three sections and the badge', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Row + Expanded (flex 1 : 2)'), findsOneWidget);
    expect(find.text('Column'), findsOneWidget);
    expect(find.text('Stack + Positioned'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('Expanded flex 2 is twice as wide as flex 1', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    final double w1 = tester
        .getSize(find.widgetWithText(DemoBox, 'flex 1'))
        .width;
    final double w2 = tester
        .getSize(find.widgetWithText(DemoBox, 'flex 2'))
        .width;

    expect(w2, closeTo(w1 * 2, 0.01));
  });
}
