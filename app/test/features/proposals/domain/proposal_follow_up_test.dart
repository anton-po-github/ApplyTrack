import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal_follow_up.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

import '../../../support/proposal_fixtures.dart';

void main() {
  final CalendarDate today = CalendarDate(2026, 11, 6);

  bool due(ProposalStatus status, CalendarDate? date) =>
      makeProposal(1, status: status, followUpDate: date).isFollowUpDue(today);

  test('Sent or Viewed with a date of today is due', () {
    expect(due(ProposalStatus.sent, today), isTrue);
    expect(due(ProposalStatus.viewed, today), isTrue);
  });

  test('a date in the past is due', () {
    expect(due(ProposalStatus.sent, CalendarDate(2026, 11, 5)), isTrue);
    expect(due(ProposalStatus.viewed, CalendarDate(2025, 1, 1)), isTrue);
  });

  test('a date in the future is not due', () {
    expect(due(ProposalStatus.sent, CalendarDate(2026, 11, 7)), isFalse);
    expect(due(ProposalStatus.viewed, CalendarDate(2027, 1, 1)), isFalse);
  });

  test('no date is never due', () {
    expect(due(ProposalStatus.sent, null), isFalse);
  });

  test('other statuses are never due', () {
    for (final ProposalStatus status in <ProposalStatus>[
      ProposalStatus.draft,
      ProposalStatus.interview,
      ProposalStatus.won,
      ProposalStatus.lost,
    ]) {
      expect(due(status, CalendarDate(2020, 1, 1)), isFalse, reason: '$status');
    }
  });
}
