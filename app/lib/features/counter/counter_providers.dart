import 'package:apply_track/features/counter/counter.dart';
import 'package:apply_track/features/counter/counter_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<CounterStore> counterStoreProvider = Provider<CounterStore>(
  (ref) => InMemoryCounterStore(),
);

final NotifierProvider<CounterNotifier, Counter> counterProvider =
    NotifierProvider<CounterNotifier, Counter>(CounterNotifier.new);

class CounterNotifier extends Notifier<Counter> {
  CounterStore get _store => ref.read(counterStoreProvider);

  @override
  Counter build() => ref.watch(counterStoreProvider).load();

  void increment() {
    final next = state.increment();
    if (identical(next, state)) {
      return;
    }
    state = next;
    _store.save(next);
  }

  void reset() {
    state = state.reset();
    _store.save(state);
  }
}
