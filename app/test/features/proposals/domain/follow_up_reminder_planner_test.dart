import 'package:apply_track/core/notifications/notification_id.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/follow_up_reminder_planner.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/proposal_fixtures.dart';

typedef _Row = ({
  String name,
  ProposalStatus status,
  CalendarDate? date,
  DateTime now,
  DateTime? expected,
});

void main() {
  final tomorrow = CalendarDate(2026, 11, 20);
  final today = CalendarDate(2026, 11, 19);
  final tomorrowAt9 = DateTime(2026, 11, 20, 9);
  final todayAt9 = DateTime(2026, 11, 19, 9);

  final rows = <_Row>[
    (
      name: 'Sent, tomorrow: reminds at 09:00 tomorrow',
      status: ProposalStatus.sent,
      date: tomorrow,
      now: DateTime(2026, 11, 19, 10),
      expected: tomorrowAt9,
    ),
    (
      name: 'Draft, tomorrow: reminds (only Won and Lost are closed)',
      status: ProposalStatus.draft,
      date: tomorrow,
      now: DateTime(2026, 11, 19, 10),
      expected: tomorrowAt9,
    ),
    (
      name: 'Today before 09:00: reminds today at 09:00',
      status: ProposalStatus.viewed,
      date: today,
      now: DateTime(2026, 11, 19, 8),
      expected: todayAt9,
    ),
    (
      name: 'No date: no reminder',
      status: ProposalStatus.sent,
      date: null,
      now: DateTime(2026, 11, 19, 10),
      expected: null,
    ),
    (
      name: 'Date in the past: no reminder',
      status: ProposalStatus.sent,
      date: CalendarDate(2026, 11, 18),
      now: DateTime(2026, 11, 19, 10),
      expected: null,
    ),
    (
      name: 'Today after 09:00: no reminder',
      status: ProposalStatus.sent,
      date: today,
      now: DateTime(2026, 11, 19, 10),
      expected: null,
    ),
    (
      name: 'Won, tomorrow: no reminder',
      status: ProposalStatus.won,
      date: tomorrow,
      now: DateTime(2026, 11, 19, 10),
      expected: null,
    ),
    (
      name: 'Lost, tomorrow: no reminder',
      status: ProposalStatus.lost,
      date: tomorrow,
      now: DateTime(2026, 11, 19, 10),
      expected: null,
    ),
  ];

  for (final row in rows) {
    test(row.name, () {
      final proposal = makeProposal(
        1,
        status: row.status,
        followUpDate: row.date,
      );

      final plan = planReminder(proposal, row.now);

      if (row.expected == null) {
        expect(plan, isNull);
      } else {
        expect(
          plan,
          ReminderPlan(id: notificationIdFor(proposal.id), when: row.expected!),
        );
      }
    });
  }
}
