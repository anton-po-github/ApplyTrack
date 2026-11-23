import 'package:apply_track/core/notifications/notification_id.dart';
import 'package:apply_track/core/notifications/notification_scheduler.dart';
import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/follow_up_reminder_planner.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the phone reminders in line with the proposals.
///
/// The rules live in [planReminder]. This class only runs the plan on the
/// [NotificationScheduler]. The list controller calls it after a successful
/// server answer, so the server stays the truth. Tests replace the scheduler
/// with a fake.
///
/// No method throws, because the scheduler never throws.
final Provider<FollowUpReminderService> followUpReminderServiceProvider =
    Provider<FollowUpReminderService>(
      (ref) => FollowUpReminderService(
        scheduler: ref.watch(notificationSchedulerProvider),
        clock: ref.watch(clockProvider),
      ),
    );

class FollowUpReminderService {
  new({required this._scheduler, required this._clock});

  static const String _title = 'Follow-up reminder';

  final NotificationScheduler _scheduler;
  final Clock _clock;

  /// Grows with every [clearAll]. A slow [sync] or [reconcile] that started
  /// before a sign out sees the change and stops, so it never schedules a
  /// reminder for the user who has left.
  int _generation = 0;

  /// Removes the old reminder of [proposal], then schedules the new one if
  /// the rules give a plan. The cancel always runs: if the new schedule is
  /// refused (for example no permission), the old date must not stay.
  Future<void> sync(Proposal proposal) async {
    final generation = _generation;
    final plan = planReminder(proposal, _clock());
    await _scheduler.cancel(plan?.id ?? notificationIdFor(proposal.id));
    if (plan == null || generation != _generation) {
      return;
    }
    await _scheduler.schedule(
      id: plan.id,
      title: _title,
      body: _bodyFor(proposal),
      when: plan.when,
      // The tap handler reads this id and opens the proposal.
      payload: proposal.id,
    );
  }

  /// Removes the reminder of the proposal with [id].
  Future<void> remove(String id) => _scheduler.cancel(notificationIdFor(id));

  /// Runs [sync] for every row, one after the other. [proposals] must come
  /// from a server answer. It stops when [clearAll] runs meanwhile.
  ///
  /// A row whose reminder already came is skipped. A cancel would also remove
  /// its notification from the phone before the user has seen it.
  Future<void> reconcile(Iterable<Proposal> proposals) async {
    final generation = _generation;
    for (final proposal in proposals) {
      if (generation != _generation) {
        return;
      }
      if (hasReminderTimePassed(proposal, _clock())) {
        continue;
      }
      await sync(proposal);
    }
  }

  /// Removes every reminder (sign out, 401, another user).
  Future<void> clearAll() {
    _generation++;
    return _scheduler.cancelAll();
  }

  static String _bodyFor(Proposal proposal) {
    final company = proposal.company;
    if (company == null || company.isEmpty) {
      return proposal.title;
    }
    return '${proposal.title} ($company)';
  }
}
