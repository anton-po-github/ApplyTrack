import 'package:apply_track/features/counter/counter.dart';
import 'package:apply_track/features/counter/counter_store.dart';

final class FakeCounterStore implements CounterStore {
  FakeCounterStore([this.initial = const Counter()]);

  final Counter initial;
  final List<Counter> saved = <Counter>[];

  @override
  Counter load() => initial;

  @override
  void save(Counter counter) {
    saved.add(counter);
  }
}
