import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// A GUID-shaped id. Same [n] gives the same id.
String proposalId(int n) =>
    '0190a1b2-0000-7000-8000-${n.toString().padLeft(12, '0')}';

Proposal makeProposal(
  int n, {
  String? title,
  ProposalStatus status = ProposalStatus.draft,
}) => Proposal(
  id: proposalId(n),
  title: title ?? 'Proposal $n',
  platform: ProposalPlatform.upwork,
  status: status,
  createdAtMs: n,
  updatedAtMs: n,
);

/// A draft that passes all validators.
ProposalDraft validDraft({
  String title = 'Flutter app',
  ProposalStatus status = ProposalStatus.draft,
}) => ProposalDraft(
  title: title,
  platform: ProposalPlatform.upwork,
  status: status,
);

ApiResult<ProposalPage> pageOf(List<Proposal> items, {String? next}) =>
    ApiOk<ProposalPage>(ProposalPage(items: items, nextCursor: next));
