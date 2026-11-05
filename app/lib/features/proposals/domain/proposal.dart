import 'package:apply_track/core/api/json_fields.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// One proposal as the server sends it (`ProposalResponse` in 07).
final class Proposal {
  const Proposal({
    required this.id,
    required this.title,
    required this.platform,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.company,
    this.budget,
    this.followUpDate,
    this.link,
    this.notes,
  });

  /// A wrong shape throws [FormatException].
  factory Proposal.fromJson(Map<String, Object?> json) {
    final String? followUp = json.optionalString('followUpDate');
    return Proposal(
      id: json.requireString('id'),
      title: json.requireString('title'),
      company: json.optionalString('company'),
      platform: ProposalPlatform.fromApi(json.requireInt('platform')),
      status: ProposalStatus.fromApi(json.requireInt('status')),
      budget: json.optionalNum('budget')?.toDouble(),
      followUpDate: followUp == null ? null : CalendarDate.parse(followUp),
      link: json.optionalString('link'),
      notes: json.optionalString('notes'),
      createdAtMs: json.requireInt('createdAtMs'),
      updatedAtMs: json.requireInt('updatedAtMs'),
    );
  }

  final String id;
  final String title;
  final String? company;
  final ProposalPlatform platform;
  final ProposalStatus status;
  final double? budget;
  final CalendarDate? followUpDate;
  final String? link;
  final String? notes;

  /// Unix time in MILLISECONDS.
  final int createdAtMs;
  final int updatedAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  @override
  bool operator ==(Object other) =>
      other is Proposal &&
      other.id == id &&
      other.title == title &&
      other.company == company &&
      other.platform == platform &&
      other.status == status &&
      other.budget == budget &&
      other.followUpDate == followUpDate &&
      other.link == link &&
      other.notes == notes &&
      other.createdAtMs == createdAtMs &&
      other.updatedAtMs == updatedAtMs;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    company,
    platform,
    status,
    budget,
    followUpDate,
    link,
    notes,
    createdAtMs,
    updatedAtMs,
  );
}
