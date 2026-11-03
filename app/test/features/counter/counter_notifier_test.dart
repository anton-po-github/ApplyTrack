import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apply_track/features/counter/counter.dart';
import 'package:apply_track/features/counter/counter_providers.dart';

import 'fake_counter_store.dart';

void main() {
  ProviderContainer makeContainer(FakeCounterStore store) {
    final ProviderContainer container = ProviderContainer(
      overrides: [counterStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts with the value from the store', () {
    final ProviderContainer container = makeContainer(
      FakeCounterStore(const Counter(value: 3)),
    );

    expect(container.read(counterProvider).value, 3);
  });

  test('increment updates state and saves', () {
    final FakeCounterStore store = FakeCounterStore();
    final ProviderContainer container = makeContainer(store);

    container.read(counterProvider.notifier).increment();

    expect(container.read(counterProvider).value, 1);
    expect(store.saved.single.value, 1);
  });

  test('increment at max does not save', () {
    final FakeCounterStore store = FakeCounterStore(const Counter(value: 5));
    final ProviderContainer container = makeContainer(store);

    container.read(counterProvider.notifier).increment();

    expect(container.read(counterProvider).value, 5);
    expect(store.saved, isEmpty);
  });
}
