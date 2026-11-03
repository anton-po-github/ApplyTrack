import 'package:flutter_test/flutter_test.dart';
import 'package:apply_track/core/layout/window_size.dart';

void main() {
  test('under 600 is compact', () {
    expect(WindowSize.fromWidth(0), WindowSize.compact);
    expect(WindowSize.fromWidth(599.9), WindowSize.compact);
  });

  test('600 to 839 is medium', () {
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839.9), WindowSize.medium);
  });

  test('840 and more is expanded', () {
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
    expect(WindowSize.fromWidth(2000), WindowSize.expanded);
  });
}
