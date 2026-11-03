import 'package:phase2_widgets/features/counter/counter.dart';

abstract interface class CounterStore {
  Counter load();
  void save(Counter counter);
}

final class InMemoryCounterStore implements CounterStore {
  Counter _counter = const Counter();

  @override
  Counter load() => _counter;

  @override
  void save(Counter counter) {
    _counter = counter;
  }
}
