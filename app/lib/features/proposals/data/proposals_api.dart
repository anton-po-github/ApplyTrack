import 'dart:math' as math;

import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_id.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_validators.dart';

/// Raw calls from 07-api-schema.md (endpoints 6 to 10). No logic here.
/// The server checks every field again. The state layer owns the rules.
abstract interface class ProposalsApi {
  static const int defaultLimit = 20;
  static const int maxLimit = 50;

  /// Newest first. Send the same [status] and [q] while you page.
  Future<ApiResult<ProposalPage>> list({
    ProposalStatus? status,
    String? q,
    String? cursor,
    int limit = defaultLimit,
  });

  Future<ApiResult<Proposal>> get(String id);

  Future<ApiResult<Proposal>> create(ProposalDraft draft);

  /// Full replace: the draft always has all fields.
  Future<ApiResult<Proposal>> update(String id, ProposalDraft draft);

  /// Soft delete on the server. A second delete gives `not_found`.
  Future<ApiResult<void>> delete(String id);
}

final class HttpProposalsApi implements ProposalsApi {
  const new(this._client);

  static const String _base = '/api/proposals';

  final ApiClient _client;

  @override
  Future<ApiResult<ProposalPage>> list({
    ProposalStatus? status,
    String? q,
    String? cursor,
    int limit = ProposalsApi.defaultLimit,
  }) => _client.get<ProposalPage>(
    _base,
    query: <String, Object?>{
      'status': status?.apiValue,
      'q': ProposalValidators.normalizeSearchQuery(q),
      'cursor': (cursor == null || cursor.isEmpty) ? null : cursor,
      'limit': math.min(math.max(limit, 1), ProposalsApi.maxLimit),
    },
    parse: ProposalPage.fromJson,
  );

  @override
  Future<ApiResult<Proposal>> get(String id) {
    final path = _pathFor(id);
    if (path == null) {
      return Future<ApiResult<Proposal>>.value(_badId<Proposal>());
    }
    return _client.get<Proposal>(path, parse: Proposal.fromJson);
  }

  @override
  Future<ApiResult<Proposal>> create(ProposalDraft draft) => _client
      .post<Proposal>(_base, body: draft.toJson(), parse: Proposal.fromJson);

  @override
  Future<ApiResult<Proposal>> update(String id, ProposalDraft draft) {
    final path = _pathFor(id);
    if (path == null) {
      return Future<ApiResult<Proposal>>.value(_badId<Proposal>());
    }
    return _client.put<Proposal>(
      path,
      body: draft.toJson(),
      parse: Proposal.fromJson,
    );
  }

  @override
  Future<ApiResult<void>> delete(String id) {
    final path = _pathFor(id);
    if (path == null) return Future<ApiResult<void>>.value(_badId<void>());
    return _client.delete(path);
  }

  /// Null when [id] is not a GUID. Then we send nothing.
  static String? _pathFor(String id) =>
      ProposalId.isValid(id) ? '$_base/$id' : null;

  static ApiResult<T> _badId<T>() => ApiErr<T>(
    const ApiError(
      code: ApiErrorCodes.badRequest,
      message: 'This proposal id is not valid.',
    ),
  );
}
