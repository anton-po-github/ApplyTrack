import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_validators.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposal_list_state.dart';
import 'package:apply_track/features/proposals/ui/proposal_card.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The first tab: search, status filter, the list and the Add button.
/// It only shows the state of [proposalListProvider]. It holds no data.
class ProposalListScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ProposalListScreen> createState() => _ProposalListScreenState();
}

class _ProposalListScreenState extends ConsumerState<ProposalListScreen> {
  /// Load the next page when less than this many pixels are left.
  static const double _loadMoreDistance = 300;

  late final TextEditingController _search;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(proposalListProvider).query ?? '',
    );
    _scroll.addListener(_loadMoreIfNearEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  ProposalListController get _controller =>
      ref.read(proposalListProvider.notifier);

  /// The controller ignores the call unless the list is idle and has a
  /// next page, so it is safe to call it often.
  void _loadMoreIfNearEnd() {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    if (_scroll.position.extentAfter < _loadMoreDistance) {
      unawaited(_controller.loadMore());
    }
  }

  void _clearSearchText() {
    _search.clear();
    setState(() {});
    _controller.setQuery(null);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {});
    unawaited(_controller.clearFilters());
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(proposalListProvider);
    final today = CalendarDate.fromDateTime(ref.read(clockProvider)());

    // A short list may not scroll at all. Then the scroll listener never
    // runs, so we also check after each frame.
    if (list.phase == ProposalListPhase.loaded && list.hasMore) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfNearEnd(),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-proposal'),
        onPressed: () => context.push(AppRoutes.proposalNew),
        icon: const Icon(Icons.add),
        label: const Text('Add proposal'),
      ),
      body: MaxContentWidth(
        maxWidth: 800,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const Key('search-field'),
                controller: _search,
                maxLength: ProposalValidators.searchMax,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by title',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('search-clear'),
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearchText,
                        ),
                ),
                onChanged: (text) {
                  setState(() {});
                  _controller.setQuery(text);
                },
                onSubmitted: _controller.setQuery,
              ),
            ),
            _FilterChips(
              selected: list.status,
              onSelected: _controller.setStatus,
            ),
            if (list.phase == ProposalListPhase.error && !list.isEmpty)
              _ErrorBanner(error: list.error, onRetry: _controller.retry),
            Expanded(
              child: _Content(
                list: list,
                today: today,
                scroll: _scroll,
                onRefresh: _controller.refresh,
                onRetry: _controller.retry,
                onClearFilters: _clearFilters,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final ProposalStatus? selected;
  final Future<void> Function(ProposalStatus? status) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          _chip(label: 'All', status: null),
          for (final ProposalStatus status in ProposalStatus.values)
            _chip(label: status.label, status: status),
        ],
      ),
    );
  }

  Widget _chip({required String label, required ProposalStatus? status}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey<String>('filter-${status?.name ?? 'all'}'),
        label: Text(label),
        selected: selected == status,
        onSelected: (_) => onSelected(status),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const new({
    required this.list,
    required this.today,
    required this.scroll,
    required this.onRefresh,
    required this.onRetry,
    required this.onClearFilters,
  });

  final ProposalListState list;
  final CalendarDate today;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return switch (list.phase) {
        ProposalListPhase.loading ||
        ProposalListPhase.loadingMore => const Center(
          child: CircularProgressIndicator(key: Key('list-loading')),
        ),
        ProposalListPhase.error => _PullToRefresh(
          onRefresh: onRefresh,
          child: _Message(
            key: const Key('list-error'),
            icon: Icons.error_outline,
            text: list.error == null
                ? 'Something went wrong.'
                : apiErrorMessage(list.error!),
            action: FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ),
        ProposalListPhase.loaded => _PullToRefresh(
          onRefresh: onRefresh,
          child: list.hasFilter
              ? _Message(
                  key: const Key('list-empty-filtered'),
                  icon: Icons.search_off,
                  text: 'No proposals match your search or filter.',
                  action: TextButton(
                    onPressed: onClearFilters,
                    child: const Text('Clear filters'),
                  ),
                )
              : const _Message(
                  key: Key('list-empty'),
                  icon: Icons.inbox_outlined,
                  text:
                      'No proposals yet. Tap "Add proposal" to create '
                      'your first one.',
                ),
        ),
      };
    }

    final loadingMore = list.phase == ProposalListPhase.loadingMore;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        key: const Key('proposal-list'),
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        // Space for the Add button, so it never hides the last card.
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: list.length + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(key: Key('list-loading-more')),
              ),
            );
          }
          final proposal = list.proposalAt(index);
          return ProposalCard(
            key: ValueKey<String>('proposal-card-${proposal.id}'),
            proposal: proposal,
            today: today,
            onTap: () => context.push(AppRoutes.proposal(proposal.id)),
          );
        },
      ),
    );
  }
}

/// Lets the user pull to refresh on a screen that has no list items.
class _PullToRefresh extends StatelessWidget {
  const new({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(height: constraints.maxHeight, child: child),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.icon, required this.text, super.key, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// An error while old items are still on screen.
class _ErrorBanner extends StatelessWidget {
  const new({required this.error, required this.onRetry});

  final ApiError? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('list-error-banner'),
      color: scheme.errorContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error == null
                    ? 'Something went wrong.'
                    : apiErrorMessage(error!),
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
