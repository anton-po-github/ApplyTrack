import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:apply_track/features/counter/counter.dart';
import 'package:apply_track/features/counter/counter_providers.dart';

class CounterScreen extends ConsumerWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Counter counter = ref.watch(counterProvider);
    final CounterNotifier notifier = ref.read(counterProvider.notifier);
    final bool canAdd = counter.canIncrement;

    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(counter.value.toString(), style: theme.textTheme.displayLarge),
            const SizedBox(height: 16),
            TextButton(onPressed: notifier.reset, child: const Text('Reset')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: canAdd ? notifier.increment : null,
        tooltip: 'Add',
        elevation: canAdd ? null : 0,
        backgroundColor: canAdd
            ? null
            : theme.colorScheme.onSurface.withValues(alpha: 0.12),
        foregroundColor: canAdd
            ? null
            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
        child: const Icon(Icons.add),
      ),
    );
  }
}
