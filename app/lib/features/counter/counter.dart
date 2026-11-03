final class Counter {
  const Counter({this.value = 0, this.max = 5})
    : assert(value >= 0 && value <= max);

  final int value;
  final int max;

  bool get canIncrement => value < max;

  Counter increment() =>
      canIncrement ? Counter(value: value + 1, max: max) : this;

  Counter reset() => Counter(max: max);
}
