import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

enum ProposalListPhase {
  /// First page (or a new filter) is on the way.
  loading,
  loaded,
  loadingMore,

  /// The last request failed. Items already shown are kept.
  error,
}

/// The loaded part of the list.
///
/// [byId] gives O(1) reads by id. [ids] keeps the server order (newest
/// first), so [proposalAt] is O(1) too. Both collections are unmodifiable.
final class ProposalListState {
  const new({
    this.byId = const <String, Proposal>{},
    this.ids = const <String>[],
    this.nextCursor,
    this.status,
    this.query,
    this.phase = ProposalListPhase.loading,
    this.error,
    this.isWriting = false,
  });

  static const Object _keep = Object();

  final Map<String, Proposal> byId;
  final List<String> ids;

  /// Null means this is the last page.
  final String? nextCursor;

  /// The filter that is applied now. Null means "All".
  final ProposalStatus? status;

  /// The search text that is applied now. Trimmed. Null means "no search".
  final String? query;

  final ProposalListPhase phase;

  /// Set only in the [ProposalListPhase.error] phase.
  final ApiError? error;

  /// True while a create, update or delete runs. Use it to block double taps.
  final bool isWriting;

  int get length => ids.length;
  bool get isEmpty => ids.isEmpty;
  bool get hasMore => nextCursor != null;
  bool get hasFilter => status != null || query != null;

  /// O(1). [index] must be from 0 to [length] - 1.
  Proposal proposalAt(int index) => byId[ids[index]]!;

  /// O(1). Null when the id is not loaded.
  Proposal? proposalById(String id) => byId[id];

  /// Pass `null` for [nextCursor], [status], [query] or [error] to clear it.
  /// Leave it out to keep the old value.
  ProposalListState copyWith({
    Map<String, Proposal>? byId,
    List<String>? ids,
    Object? nextCursor = _keep,
    Object? status = _keep,
    Object? query = _keep,
    Object? error = _keep,
    ProposalListPhase? phase,
    bool? isWriting,
  }) => ProposalListState(
    byId: byId ?? this.byId,
    ids: ids ?? this.ids,
    nextCursor: identical(nextCursor, _keep)
        ? this.nextCursor
        : nextCursor as String?,
    status: identical(status, _keep) ? this.status : status as ProposalStatus?,
    query: identical(query, _keep) ? this.query : query as String?,
    phase: phase ?? this.phase,
    error: identical(error, _keep) ? this.error : error as ApiError?,
    isWriting: isWriting ?? this.isWriting,
  );
}
