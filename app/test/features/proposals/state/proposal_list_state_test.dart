import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/proposal_fixtures.dart';

void main() {
  test('starts empty, in the loading phase, with no filter', () {
    const state = ProposalListState();

    expect(state.isEmpty, isTrue);
    expect(state.length, 0);
    expect(state.phase, ProposalListPhase.loading);
    expect(state.hasMore, isFalse);
    expect(state.hasFilter, isFalse);
    expect(state.isWriting, isFalse);
    expect(state.error, isNull);
  });

  test('proposalAt and proposalById read by index and by id', () {
    final state = ProposalListState(
      byId: {proposalId(1): makeProposal(1), proposalId(2): makeProposal(2)},
      ids: [proposalId(2), proposalId(1)],
    );

    expect(state.length, 2);
    expect(state.proposalAt(0), makeProposal(2));
    expect(state.proposalAt(1), makeProposal(1));
    expect(state.proposalById(proposalId(1)), makeProposal(1));
    expect(state.proposalById('missing'), isNull);
  });

  test('hasMore and hasFilter follow cursor, status and query', () {
    const state = ProposalListState(nextCursor: 'c1', query: 'flutter');

    expect(state.hasMore, isTrue);
    expect(state.hasFilter, isTrue);
    expect(
      const ProposalListState(status: ProposalStatus.won).hasFilter,
      isTrue,
    );
  });

  group('copyWith', () {
    const failure = ApiError.network();
    const full = ProposalListState(
      nextCursor: 'c1',
      status: ProposalStatus.sent,
      query: 'q',
      phase: ProposalListPhase.error,
      error: failure,
      isWriting: true,
    );

    test('keeps every value that is left out', () {
      final copy = full.copyWith();

      expect(copy.nextCursor, 'c1');
      expect(copy.status, ProposalStatus.sent);
      expect(copy.query, 'q');
      expect(copy.phase, ProposalListPhase.error);
      expect(copy.error, same(failure));
      expect(copy.isWriting, isTrue);
    });

    test('clears nullable values when null is passed', () {
      final copy = full.copyWith(
        nextCursor: null,
        status: null,
        query: null,
        error: null,
      );

      expect(copy.nextCursor, isNull);
      expect(copy.status, isNull);
      expect(copy.query, isNull);
      expect(copy.error, isNull);
      expect(copy.phase, ProposalListPhase.error);
    });

    test('changes phase and the write flag', () {
      final copy = full.copyWith(
        phase: ProposalListPhase.loaded,
        isWriting: false,
      );

      expect(copy.phase, ProposalListPhase.loaded);
      expect(copy.isWriting, isFalse);
    });
  });
}
