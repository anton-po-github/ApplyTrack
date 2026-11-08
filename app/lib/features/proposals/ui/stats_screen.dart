import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/core/layout/window_size.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/stats_provider.dart';
import 'package:apply_track/features/proposals/ui/proposal_formatters.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The second tab: total, win rate and one card for each status.
/// It only shows the state of [statsProvider]. It holds no data.
///
/// - 1, 2 or 3 columns, by [WindowSize].
/// - A tap on a status card opens the list with that filter.
/// - Pull to refresh. The old numbers stay while it loads or after an error.
class StatsScreen extends ConsumerWidget {
  const new({super.key});

  static const double _maxWidth = 900;

  /// Number of card columns for a window size.
  static int columnsFor(WindowSize size) => switch (size) {
    WindowSize.compact => 1,
    WindowSize.medium => 2,
    WindowSize.expanded => 3,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsProvider);
    final controller = ref.read(statsProvider.notifier);
    final columns = columnsFor(
      WindowSize.fromWidth(MediaQuery.sizeOf(context).width),
    );

    void openList(ProposalStatus status) {
      unawaited(ref.read(proposalListProvider.notifier).setStatus(status));
      context.go(AppRoutes.home);
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = state.stats;
          final Widget child;
          if (stats == null) {
            // No numbers yet: a message that fills the screen.
            final error = state.error;
            child = SizedBox(
              height: constraints.maxHeight,
              child: error == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: Key('stats-loading'),
                      ),
                    )
                  : _Message(
                      key: const Key('stats-error'),
                      text: apiErrorMessage(error),
                      onRetry: controller.refresh,
                    ),
            );
          } else {
            final error = state.error;
            child = MaxContentWidth(
              maxWidth: _maxWidth,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: <Widget>[
                    if (state.isLoading)
                      const LinearProgressIndicator(
                        key: Key('stats-refreshing'),
                      ),
                    if (error != null)
                      _ErrorBanner(error: error, onRetry: controller.refresh),
                    _StatsGrid(
                      stats: stats,
                      columns: columns,
                      onStatusTap: openList,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[child],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const new({
    required this.stats,
    required this.columns,
    required this.onStatusTap,
  });

  static const double _gap = 12;

  final ProposalStats stats;
  final int columns;
  final ValueChanged<ProposalStatus> onStatusTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            SizedBox(
              width: width,
              child: _StatCard(
                key: const Key('stats-card-total'),
                valueKey: const Key('stats-value-total'),
                label: 'Total',
                value: '${stats.total}',
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                key: const Key('stats-card-win-rate'),
                valueKey: const Key('stats-value-win-rate'),
                label: 'Win rate',
                value: formatWinRate(stats.winRate),
              ),
            ),
            for (final ProposalStatus status in ProposalStatus.values)
              SizedBox(
                width: width,
                child: _StatCard(
                  key: ValueKey<String>('stats-card-${status.name}'),
                  valueKey: ValueKey<String>('stats-value-${status.name}'),
                  label: status.label,
                  value: '${stats.countFor(status)}',
                  onTap: () => onStatusTap(status),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const new({
    required this.valueKey,
    required this.label,
    required this.value,
    super.key,
    this.onTap,
  });

  final Key valueKey;
  final String label;
  final String value;

  /// Null means the card is only a number (total, win rate).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: <Widget>[
                    Text(label, style: text.titleSmall),
                    Text(value, key: valueKey, style: text.headlineMedium),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.text, required this.onRetry, super.key});

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// An error while old numbers are still on screen.
class _ErrorBanner extends StatelessWidget {
  const new({required this.error, required this.onRetry});

  final ApiError error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('stats-error-banner'),
      color: scheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                apiErrorMessage(error),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
