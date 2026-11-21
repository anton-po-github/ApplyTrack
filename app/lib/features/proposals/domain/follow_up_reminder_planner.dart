import 'package:apply_track/core/notifications/notification_id.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:meta/meta.dart';

/// The local hour at which a follow-up reminder shows.
const int followUpReminderHour = 9;

/// One reminder to schedule: the notification [id] and the moment [when]
/// (local time).
@immutable
final class ReminderPlan {
  const new({required this.id, required this.when});

  final int id;
  final DateTime when;

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && other.id == id && other.when == when;

  @override
  int get hashCode => Object.hash(id, when);

  @override
  String toString() => 'ReminderPlan(id: $id, when: $when)';
}

/// The reminder for [proposal], or null when there must be none.
///
/// The reminder shows at 09:00 local time on the follow-up date. There is no
/// reminder when:
/// - the proposal has no follow-up date,
/// - the status is Won or Lost (the work is closed),
/// - 09:00 on that date is not after [now] (a past date, or today after
///   09:00).
///
/// Draft, Sent, Viewed and Interview all get a reminder: the user chose the
/// date on purpose.
///
/// Pure and O(1). [now] is a parameter, so tests control the time.
ReminderPlan? planReminder(Proposal proposal, DateTime now) {
  final date = proposal.followUpDate;
  if (date == null || _isClosed(proposal.status)) {
    return null;
  }
  final when = _reminderTime(date);
  if (!when.isAfter(now)) {
    return null;
  }
  return ReminderPlan(id: notificationIdFor(proposal.id), when: when);
}

/// True when the proposal is still open and its reminder time has passed.
/// Its reminder already came, so nothing is waiting for it. The notification
/// may still sit on the phone, because the user has not seen it yet.
bool hasReminderTimePassed(Proposal proposal, DateTime now) {
  final date = proposal.followUpDate;
  if (date == null || _isClosed(proposal.status)) {
    return false;
  }
  return !_reminderTime(date).isAfter(now);
}

bool _isClosed(ProposalStatus status) =>
    status == ProposalStatus.won || status == ProposalStatus.lost;

DateTime _reminderTime(CalendarDate date) =>
    DateTime(date.year, date.month, date.day, followUpReminderHour);
