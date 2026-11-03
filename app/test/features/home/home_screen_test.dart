import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phase2_widgets/features/home/home_screen.dart';

void main() {
  Future<List<Offset>> cardPositions(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

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
}
