import 'package:flutter_test/flutter_test.dart';
import 'package:phase2_widgets/features/counter/counter.dart';

void main() {
  test('starts at 0', () {
    expect(const Counter().value, 0);
  });

  test('increment adds 1', () {
    expect(const Counter().increment().value, 1);
  });

  test('increment stops at max and returns the same object', () {
    const Counter atMax = Counter(value: 5);

    expect(atMax.canIncrement, isFalse);
    expect(identical(atMax.increment(), atMax), isTrue);
  });

  test('reset goes back to 0 and keeps max', () {
    final Counter reset = const Counter(value: 3, max: 8).reset();

    expect(reset.value, 0);
    expect(reset.max, 8);
  });
}
