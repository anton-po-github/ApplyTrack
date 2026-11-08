final class Counter {
  const new({this.value = 0, this.max = 5})
    : assert(value >= 0 && value <= max, 'value must be between 0 and max');

  final int value;
  final int max;

  bool get canIncrement => value < max;

  Counter increment() =>
      canIncrement ? Counter(value: value + 1, max: max) : this;

  Counter reset() => Counter(max: max);
}
