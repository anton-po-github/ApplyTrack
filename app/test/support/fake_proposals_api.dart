import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// The arguments of one `list` call.
final class ListCall {
  const ListCall({this.status, this.q, this.cursor, required this.limit});

  final ProposalStatus? status;
  final String? q;
  final String? cursor;
  final int limit;
}

typedef ListHandler = Future<ApiResult<ProposalPage>> Function(ListCall call);

/// A fake [ProposalsApi]. Set a handler to control the answer
/// (use a `Completer` inside it to keep a call "slow").
final class FakeProposalsApi implements ProposalsApi {
  final List<ListCall> listCalls = <ListCall>[];
  final List<ProposalDraft> createCalls = <ProposalDraft>[];
  final List<String> updateIds = <String>[];
  final List<String> deleteIds = <String>[];

  ListHandler listHandler = (ListCall call) async =>
      const ApiOk<ProposalPage>(ProposalPage(items: <Proposal>[]));

  Future<ApiResult<Proposal>> Function(ProposalDraft draft) createHandler = (
    ProposalDraft draft,
  ) async => const ApiErr<Proposal>(ApiError.badResponse());

  Future<ApiResult<Proposal>> Function(String id, ProposalDraft draft)
  updateHandler = (String id, ProposalDraft draft) async =>
      const ApiErr<Proposal>(ApiError.badResponse());

  Future<ApiResult<void>> Function(String id) deleteHandler = (
    String id,
  ) async => const ApiOk<void>(null);

  @override
  Future<ApiResult<ProposalPage>> list({
    ProposalStatus? status,
    String? q,
    String? cursor,
    int limit = ProposalsApi.defaultLimit,
  }) {
    final ListCall call = ListCall(
      status: status,
      q: q,
      cursor: cursor,
      limit: limit,
    );
    listCalls.add(call);
    return listHandler(call);
  }

  @override
  Future<ApiResult<Proposal>> get(String id) =>
      throw UnimplementedError('Not used by the list state.');

  @override
  Future<ApiResult<Proposal>> create(ProposalDraft draft) {
    createCalls.add(draft);
    return createHandler(draft);
  }

  @override
  Future<ApiResult<Proposal>> update(String id, ProposalDraft draft) {
    updateIds.add(id);
    return updateHandler(id, draft);
  }

  @override
  Future<ApiResult<void>> delete(String id) {
    deleteIds.add(id);
    return deleteHandler(id);
  }
}
