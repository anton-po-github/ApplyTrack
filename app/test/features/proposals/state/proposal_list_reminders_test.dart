import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/notifications/notification_id.dart';
import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_notification_scheduler.dart';
import '../../../support/fake_proposal_cache.dart';
import '../../../support/fake_proposals_api.dart';
import '../../../support/proposal_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 19, 10);
  final tomorrow = CalendarDate(2026, 11, 20);
  final inThreeDays = CalendarDate(2026, 11, 22);

  late FakeProposalsApi api;
  late FakeProposalCache cache;
  late FakeNotificationScheduler scheduler;
  late ProviderContainer container;

  ProposalListController controller() =>
      container.read(proposalListProvider.notifier);

  /// Creates the controller (it listens like a widget) and lets the first
  /// request finish. Set the fake handlers before you call it.
  Future<void> start() async {
    container.listen(proposalListProvider, (previous, next) {});
    await pumpEventQueue();
  }

  List<DateTime> pendingTimes() =>
      scheduler.pending.map((reminder) => reminder.when).toList();

  setUp(() {
    api = FakeProposalsApi();
    cache = FakeProposalCache();
    scheduler = FakeNotificationScheduler(now: () => now);
    container = ProviderContainer(
      overrides: [
        proposalsApiProvider.overrideWithValue(api),
        proposalCacheProvider.overrideWithValue(cache),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        currentUserIdProvider.overrideWithValue('u1'),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  test('writes keep the reminder in line with the server answer', () async {
    await start();

    // Create: a reminder at 09:00 on the follow-up date.
    api.createHandler = (draft) async => ApiOk<Proposal>(
      makeProposal(1, status: ProposalStatus.sent, followUpDate: tomorrow),
    );
    await controller().create(validDraft());
    await pumpEventQueue();
    expect(scheduler.pending, hasLength(1));
    expect(scheduler.pending.single.id, notificationIdFor(proposalId(1)));
    expect(scheduler.pending.single.when, DateTime(2026, 11, 20, 9));
    expect(scheduler.pending.single.body, 'Proposal 1');
    expect(scheduler.pending.single.payload, proposalId(1));

    // Update with another date: the same reminder moves.
    api.updateHandler = (id, draft) async => ApiOk<Proposal>(
      makeProposal(1, status: ProposalStatus.sent, followUpDate: inThreeDays),
    );
    await controller().update(proposalId(1), validDraft());
    await pumpEventQueue();
    expect(pendingTimes(), [DateTime(2026, 11, 22, 9)]);

    // Update to Won: the reminder is gone.
    api.updateHandler = (id, draft) async => ApiOk<Proposal>(
      makeProposal(1, status: ProposalStatus.won, followUpDate: inThreeDays),
    );
    await controller().update(proposalId(1), validDraft());
    await pumpEventQueue();
    expect(scheduler.pending, isEmpty);

    // Back to Sent: the reminder is back. Delete: it is gone again.
    api.updateHandler = (id, draft) async => ApiOk<Proposal>(
      makeProposal(1, status: ProposalStatus.sent, followUpDate: tomorrow),
    );
    await controller().update(proposalId(1), validDraft());
    await pumpEventQueue();
    expect(pendingTimes(), [DateTime(2026, 11, 20, 9)]);
    await controller().delete(proposalId(1));
    await pumpEventQueue();
    expect(scheduler.pending, isEmpty);
  });

  test('reminders follow the server rows after page 1 loads', () async {
    // The saved copy and the phone still know an old reminder for row 1.
    await cache.replaceFirstPage('u1', [
      makeProposal(1, status: ProposalStatus.sent, followUpDate: tomorrow),
      makeProposal(9, status: ProposalStatus.sent, followUpDate: tomorrow),
    ]);
    await scheduler.schedule(
      id: notificationIdFor(proposalId(1)),
      title: 'old',
      body: 'old',
      when: DateTime(2026, 11, 20, 9),
    );
    // The server says: row 1 is Won now, row 2 needs a reminder, row 3 has
    // no date. Row 9 is only in the saved copy.
    api.listHandler = (call) async => pageOf([
      makeProposal(2, followUpDate: tomorrow),
      makeProposal(1, status: ProposalStatus.won, followUpDate: tomorrow),
      makeProposal(3, status: ProposalStatus.sent),
    ]);

    await start();

    expect(scheduler.pending.map((reminder) => reminder.id), [
      notificationIdFor(proposalId(2)),
    ]);
  });

  test('reconcile keeps the notification of a reminder that came', () async {
    // Row 4: Sent, the date was yesterday. Its reminder came already, and
    // the user may not have seen it yet. Row 5 is Won: nothing to remind.
    api.listHandler = (call) async => pageOf([
      makeProposal(
        4,
        status: ProposalStatus.sent,
        followUpDate: CalendarDate(2026, 11, 18),
      ),
      makeProposal(5, status: ProposalStatus.won, followUpDate: tomorrow),
    ]);

    await start();

    expect(
      scheduler.cancelledIds,
      isNot(contains(notificationIdFor(proposalId(4)))),
    );
    expect(scheduler.cancelledIds, contains(notificationIdFor(proposalId(5))));
  });
}
