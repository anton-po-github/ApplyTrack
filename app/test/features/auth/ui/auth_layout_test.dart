import 'package:apply_track/features/auth/ui/auth_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: AuthLayout(
        description: 'Short text.',
        child: SizedBox(height: 200, child: Text('FORM')),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the brand name and the description', (tester) async {
    await _pump(tester, const Size(800, 1000));

    expect(find.text('ApplyTrack'), findsOneWidget);
    expect(find.text('Short text.'), findsOneWidget);
    expect(find.text('FORM'), findsOneWidget);
  });

  for (final size in const <Size>[
    Size(360, 740), // phone
    Size(800, 1000), // tablet
    Size(1920, 1080), // desktop
  ]) {
    testWidgets('is centered on both axes at $size', (tester) async {
      await _pump(tester, size);

      final center = tester.getCenter(find.byKey(AuthLayout.contentKey));
      expect(center.dx, closeTo(size.width / 2, 1));
      expect(center.dy, closeTo(size.height / 2, 1));
    });
  }

  testWidgets('scrolls on a very small screen and does not overflow', (
    tester,
  ) async {
    await _pump(tester, const Size(320, 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
