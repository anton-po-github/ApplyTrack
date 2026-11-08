import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The numbers for the stats screen.
///
/// [stats] is the last good answer. It stays while a new request runs and
/// after a failed request, so the screen never goes blank on a refresh.
final class StatsState {
  const new({this.stats, this.isLoading = false, this.error});

  static const Object _keep = Object();

  /// Null until the first good answer.
  final ProposalStats? stats;

  final bool isLoading;

  /// The last request failed. Cleared when a new request starts.
  final ApiError? error;

  bool get hasData => stats != null;

  /// Pass `null` for [stats] or [error] to clear it.
  /// Leave it out to keep the old value.
  StatsState copyWith({
    Object? stats = _keep,
    bool? isLoading,
    Object? error = _keep,
  }) => StatsState(
    stats: identical(stats, _keep) ? this.stats : stats as ProposalStats?,
    isLoading: isLoading ?? this.isLoading,
    error: identical(error, _keep) ? this.error : error as ApiError?,
  );
}

final NotifierProvider<StatsController, StatsState> statsProvider =
    NotifierProvider<StatsController, StatsState>(StatsController.new);

/// Reads `GET /api/stats` (one row on the server, so it is fast).
///
/// - It loads when the user signs in.
/// - It loads again after every successful write of the proposal list
///   (`proposalsChangedProvider`).
/// - When the user id changes (sign-out, 401, another user), `build` runs
///   again and the numbers are dropped.
class StatsController extends Notifier<StatsState> {
  /// Grows with every request. An answer counts only if it is still the
  /// newest request.
  int _request = 0;

  /// The user this build belongs to. Riverpod rebuilds a moment AFTER the
  /// user changes, so an answer can arrive in between. We drop such an answer.
  String? _buildUserId;

  @override
  StatsState build() {
    final userId = ref.watch(currentUserIdProvider);
    _buildUserId = userId;
    _request++;
    // Not `watch`: a write must not drop the last good numbers.
    ref.listen<int>(
      proposalsChangedProvider,
      (previous, next) => unawaited(refresh()),
    );
    if (userId != null) {
      unawaited(Future<void>.microtask(refresh));
    }
    return StatsState(isLoading: userId != null);
  }

  /// Loads the numbers again. The old numbers stay on screen while it runs.
  /// Used by pull to refresh, by Retry and after every write.
  Future<void> refresh() async {
    if (!ref.mounted || ref.read(currentUserIdProvider) == null) {
      return;
    }
    final request = ++_request;
    state = state.copyWith(isLoading: true, error: null);

    final result = await ref.read(statsApiProvider).getStats();
    if (!_isCurrent(request)) {
      return;
    }
    switch (result) {
      case ApiOk<ProposalStats>(:final ProposalStats value):
        state = StatsState(stats: value);
      case ApiErr<ProposalStats>(:final ApiError error):
        state = state.copyWith(isLoading: false, error: error);
    }
  }

  bool _isCurrent(int request) =>
      ref.mounted &&
      request == _request &&
      ref.read(currentUserIdProvider) == _buildUserId;
}
