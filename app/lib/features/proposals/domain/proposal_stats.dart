import 'package:apply_track/core/api/json_fields.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// Counters from `GET /api/stats` (`StatsResponse` in 07).
final class ProposalStats {
  const ProposalStats({
    required this.total,
    required this.draft,
    required this.sent,
    required this.viewed,
    required this.interview,
    required this.won,
    required this.lost,
  });

  factory ProposalStats.fromJson(Map<String, Object?> json) => ProposalStats(
    total: json.requireInt('total'),
    draft: json.requireInt('draft'),
    sent: json.requireInt('sent'),
    viewed: json.requireInt('viewed'),
    interview: json.requireInt('interview'),
    won: json.requireInt('won'),
    lost: json.requireInt('lost'),
  );

  static const ProposalStats zero = ProposalStats(
    total: 0,
    draft: 0,
    sent: 0,
    viewed: 0,
    interview: 0,
    won: 0,
    lost: 0,
  );

  final int total;
  final int draft;
  final int sent;
  final int viewed;
  final int interview;
  final int won;
  final int lost;

  /// Won / (Won + Lost), from 0.0 to 1.0.
  /// Null when nothing is decided yet (the UI shows a dash).
  double? get winRate {
    final int decided = won + lost;
    return decided == 0 ? null : won / decided;
  }

  int countFor(ProposalStatus status) => switch (status) {
    ProposalStatus.draft => draft,
    ProposalStatus.sent => sent,
    ProposalStatus.viewed => viewed,
    ProposalStatus.interview => interview,
    ProposalStatus.won => won,
    ProposalStatus.lost => lost,
  };

  @override
  bool operator ==(Object other) =>
      other is ProposalStats &&
      other.total == total &&
      other.draft == draft &&
      other.sent == sent &&
      other.viewed == viewed &&
      other.interview == interview &&
      other.won == won &&
      other.lost == lost;

  @override
  int get hashCode =>
      Object.hash(total, draft, sent, viewed, interview, won, lost);
}
