import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// The body for create and update (`ProposalRequest` in 07).
/// It has no `id` and no `userId`: the owner comes from the token.
/// PUT is a full replace, so [toJson] always has all 8 keys.
final class ProposalDraft {
  const ProposalDraft({
    required this.title,
    required this.platform,
    required this.status,
    this.company,
    this.budget,
    this.followUpDate,
    this.link,
    this.notes,
  });

  /// Starts an edit form from the server data.
  factory ProposalDraft.fromProposal(Proposal proposal) => ProposalDraft(
    title: proposal.title,
    company: proposal.company,
    platform: proposal.platform,
    status: proposal.status,
    budget: proposal.budget,
    followUpDate: proposal.followUpDate,
    link: proposal.link,
    notes: proposal.notes,
  );

  /// A new, empty proposal for the create form.
  const ProposalDraft.empty()
    : this(
        title: '',
        platform: ProposalPlatform.upwork,
        status: ProposalStatus.draft,
      );

  final String title;
  final String? company;
  final ProposalPlatform platform;
  final ProposalStatus status;
  final double? budget;
  final CalendarDate? followUpDate;
  final String? link;
  final String? notes;

  /// Same draft with a new status (the quick "next stage" action).
  ProposalDraft withStatus(ProposalStatus newStatus) => ProposalDraft(
    title: title,
    company: company,
    platform: platform,
    status: newStatus,
    budget: budget,
    followUpDate: followUpDate,
    link: link,
    notes: notes,
  );

  /// Empty or space-only text becomes null, like on the server.
  /// The date goes out as `yyyy-MM-dd`. The budget has 2 decimals.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title.trim(),
    'company': _blankToNull(company?.trim()),
    'platform': platform.apiValue,
    'status': status.apiValue,
    'budget': budget == null ? null : _round2(budget!),
    'followUpDate': followUpDate?.toApiString(),
    'link': _blankToNull(link?.trim()),
    // Notes keep their line breaks. Only a blank note becomes null.
    'notes': _blankToNull(notes),
  };

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  static double _round2(double value) => (value * 100).round() / 100;

  @override
  bool operator ==(Object other) =>
      other is ProposalDraft &&
      other.title == title &&
      other.company == company &&
      other.platform == platform &&
      other.status == status &&
      other.budget == budget &&
      other.followUpDate == followUpDate &&
      other.link == link &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    title,
    company,
    platform,
    status,
    budget,
    followUpDate,
    link,
    notes,
  );
}
