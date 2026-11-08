import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_field.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_validators.dart';
import 'package:apply_track/features/proposals/state/proposal_list_state.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final NotifierProvider<ProposalListController, ProposalListState>
proposalListProvider =
    NotifierProvider<ProposalListController, ProposalListState>(
      ProposalListController.new,
    );

/// The proposal list for the signed-in user.
///
/// - The server answer is the truth. Local patches only copy what the
///   server sent back.
/// - When the user id changes (sign-out, 401, another user), `build` runs
///   again: the list is dropped and old answers are ignored.
class ProposalListController extends Notifier<ProposalListState> {
  static const ApiError _busyError = ApiError(
    code: ApiErrorCodes.unknown,
    message: 'Please wait a moment.',
  );

  /// Grows with every request. An answer counts only if it is still the
  /// newest request, so a slow old answer never replaces a newer one.
  int _request = 0;

  /// Grows when the user changes. A write answer from the old user is dropped.
  int _epoch = 0;

  /// The user this build belongs to. Riverpod rebuilds a moment AFTER the
  /// user changes, so an answer can arrive in between. We compare this id
  /// with the current one and drop such an answer.
  String? _buildUserId;

  Timer? _debounce;

  /// Which action the Retry button repeats after an error.
  bool _retryLoadMore = false;

  @override
  ProposalListState build() {
    final userId = ref.watch(currentUserIdProvider);
    _buildUserId = userId;
    _epoch++;
    _request++;
    _retryLoadMore = false;
    ref.onDispose(_cancelDebounce);
    if (userId != null) {
      unawaited(Future<void>.microtask(refresh));
    }
    return const ProposalListState();
  }

  // ---------------------------------------------------------------- reads

  /// Loads page 1 again with the current filter. Items stay visible while
  /// it runs. Used by pull to refresh and by Retry.
  Future<void> refresh() async {
    if (!_canRun) {
      return;
    }
    final request = ++_request;
    _retryLoadMore = false;
    final status = state.status;
    final query = state.query;
    state = state.copyWith(phase: ProposalListPhase.loading, error: null);

    final result = await ref
        .read(proposalsApiProvider)
        .list(status: status, q: query);
    if (!_isCurrent(request)) {
      return;
    }
    switch (result) {
      case ApiOk<ProposalPage>(:final ProposalPage value):
        state = _withPage(value, append: false);
      case ApiErr<ProposalPage>(:final ApiError error):
        state = state.copyWith(phase: ProposalListPhase.error, error: error);
    }
  }

  /// Loads the next page. Does nothing unless the list is idle and has a
  /// next page. After an error use [retry], so a broken server is not hit
  /// again and again while the user scrolls.
  Future<void> loadMore() async {
    if (state.phase != ProposalListPhase.loaded) {
      return;
    }
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final cursor = state.nextCursor;
    if (!_canRun || cursor == null) {
      return;
    }
    final request = ++_request;
    final status = state.status;
    final query = state.query;
    state = state.copyWith(phase: ProposalListPhase.loadingMore, error: null);

    final result = await ref
        .read(proposalsApiProvider)
        .list(status: status, q: query, cursor: cursor);
    if (!_isCurrent(request)) {
      return;
    }
    switch (result) {
      case ApiOk<ProposalPage>(:final ProposalPage value):
        _retryLoadMore = false;
        state = _withPage(value, append: true);
      case ApiErr<ProposalPage>(:final ApiError error):
        _retryLoadMore = true;
        state = state.copyWith(phase: ProposalListPhase.error, error: error);
    }
  }

  /// Repeats the request that failed. No auto-retry anywhere (also on 429).
  Future<void> retry() async {
    if (state.phase != ProposalListPhase.error) {
      return;
    }
    if (_retryLoadMore) {
      await _loadMore();
    } else {
      await refresh();
    }
  }

  /// Shows one status. Null means "All". The cursor and the items are reset.
  Future<void> setStatus(ProposalStatus? status) async {
    if (!_canRun || state.status == status) {
      return;
    }
    state = _reset(status: status, query: state.query);
    await refresh();
  }

  /// Removes the status filter and the search text, and loads page 1 again.
  /// Starts at once (no debounce) and cancels a search that is waiting.
  Future<void> clearFilters() async {
    _cancelDebounce();
    if (!_canRun || !state.hasFilter) {
      return;
    }
    state = _reset();
    await refresh();
  }

  /// Search by title. The request starts after a pause in typing.
  /// Text that the server would refuse (too long, control characters)
  /// is ignored, so it is never sent.
  void setQuery(String? text) {
    final next = ProposalValidators.normalizeSearchQuery(text);
    if (ProposalValidators.searchQuery(next) != null) {
      return;
    }
    _cancelDebounce();
    if (!_canRun || next == state.query) {
      return;
    }
    _debounce = ref.read(debounceTimerFactoryProvider)(
      ref.read(searchDebounceProvider),
      () {
        _debounce = null;
        unawaited(_applyQuery(next));
      },
    );
  }

  Future<void> _applyQuery(String? query) async {
    if (!_canRun || state.query == query) {
      return;
    }
    state = _reset(status: state.status, query: query);
    await refresh();
  }

  // --------------------------------------------------------------- writes

  /// The new item is not patched in. We load page 1 again, because the
  /// server decides the order and the filter match.
  Future<ApiResult<Proposal>> create(ProposalDraft draft) {
    final invalid = _validate<Proposal>(draft);
    if (invalid != null) {
      return Future<ApiResult<Proposal>>.value(invalid);
    }
    return _write<Proposal>(
      call: (api) => api.create(draft),
      onOk: (_) => unawaited(refresh()),
    );
  }

  /// Full replace. The server answer replaces the item in the list.
  /// The item leaves the list when it no longer matches the status filter.
  Future<ApiResult<Proposal>> update(String id, ProposalDraft draft) {
    final invalid = _validate<Proposal>(draft);
    if (invalid != null) {
      return Future<ApiResult<Proposal>>.value(invalid);
    }
    return _write<Proposal>(
      call: (api) => api.update(id, draft),
      onOk: _applyUpdated,
      onNotFound: () => _removeLocal(id),
    );
  }

  /// A `not_found` answer means the item is gone on the server. We remove it
  /// from the list too, and still return the error.
  Future<ApiResult<void>> delete(String id) => _write<void>(
    call: (api) => api.delete(id),
    onOk: (_) => _removeLocal(id),
    onNotFound: () => _removeLocal(id),
  );

  /// One write at a time. The check and the flag run without any `await`,
  /// so two fast taps cannot both pass.
  Future<ApiResult<T>> _write<T>({
    required Future<ApiResult<T>> Function(ProposalsApi api) call,
    required void Function(T value) onOk,
    void Function()? onNotFound,
  }) async {
    if (!ref.mounted) {
      return ApiErr<T>(_busyError);
    }
    if (ref.read(currentUserIdProvider) == null) {
      return ApiErr<T>(const ApiError.unauthorized());
    }
    if (state.isWriting) {
      return ApiErr<T>(_busyError);
    }
    final epoch = _epoch;
    state = state.copyWith(isWriting: true);
    try {
      final result = await call(ref.read(proposalsApiProvider));
      if (_isSameSession(epoch)) {
        switch (result) {
          case ApiOk<T>(:final T value):
            onOk(value);
            _announceChange();
          case ApiErr<T>(:final ApiError error):
            if (onNotFound != null && error.code == ApiErrorCodes.notFound) {
              onNotFound();
              _announceChange();
            }
        }
      }
      return result;
    } finally {
      if (_isSameSession(epoch)) {
        state = state.copyWith(isWriting: false);
      }
    }
  }

  /// Same checks as the form. The server checks them again.
  ApiResult<T>? _validate<T>(ProposalDraft draft) {
    final errors = ProposalValidators.draft(draft);
    if (errors.isEmpty) {
      return null;
    }
    return ApiErr<T>(
      ApiError(
        code: ApiErrorCodes.validation,
        message: 'Please fix the marked fields.',
        fields: <String, String>{
          for (final MapEntry<ProposalField, String> entry in errors.entries)
            entry.key.apiKey: entry.value,
        },
      ),
    );
  }

  void _announceChange() {
    ref.read(proposalsChangedProvider.notifier).notify();
  }

  // -------------------------------------------------------- local patches

  void _applyUpdated(Proposal updated) {
    if (!state.byId.containsKey(updated.id)) {
      return;
    }
    final filter = state.status;
    if (filter != null && updated.status != filter) {
      _removeLocal(updated.id);
      return;
    }
    final map = Map<String, Proposal>.of(state.byId);
    map[updated.id] = updated;
    state = state.copyWith(byId: Map<String, Proposal>.unmodifiable(map));
  }

  void _removeLocal(String id) {
    if (!state.byId.containsKey(id)) {
      return;
    }
    final map = Map<String, Proposal>.of(state.byId)..remove(id);
    final ids = List<String>.of(state.ids)..remove(id);
    state = state.copyWith(
      byId: Map<String, Proposal>.unmodifiable(map),
      ids: List<String>.unmodifiable(ids),
    );
  }

  // -------------------------------------------------------------- helpers

  bool get _canRun => ref.mounted && ref.read(currentUserIdProvider) != null;

  bool _isCurrent(int request) =>
      ref.mounted && request == _request && _isSameUser;

  bool _isSameSession(int epoch) =>
      ref.mounted && epoch == _epoch && _isSameUser;

  bool get _isSameUser => ref.read(currentUserIdProvider) == _buildUserId;

  void _cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  /// A new filter: no items, no cursor. A running write keeps its flag.
  ProposalListState _reset({ProposalStatus? status, String? query}) =>
      ProposalListState(
        status: status,
        query: query,
        isWriting: state.isWriting,
      );

  ProposalListState _withPage(ProposalPage page, {required bool append}) {
    final map = append
        ? Map<String, Proposal>.of(state.byId)
        : <String, Proposal>{};
    final ids = append ? List<String>.of(state.ids) : <String>[];
    for (final item in page.items) {
      if (!map.containsKey(item.id)) {
        ids.add(item.id);
      }
      map[item.id] = item;
    }
    // A cursor that did not move would repeat the same page for ever.
    final next = append && page.nextCursor == state.nextCursor
        ? null
        : page.nextCursor;
    return state.copyWith(
      byId: Map<String, Proposal>.unmodifiable(map),
      ids: List<String>.unmodifiable(ids),
      nextCursor: next,
      phase: ProposalListPhase.loaded,
      error: null,
    );
  }
}
