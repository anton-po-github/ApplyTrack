import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:apply_track/features/proposals/state/follow_up_reminder_cleaner.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_notification_scheduler.dart';

/// A user id that the test can change, like a sign in or a sign out.
class _TestUserId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final NotifierProvider<_TestUserId, String?> _testUserIdProvider =
    NotifierProvider<_TestUserId, String?>(_TestUserId.new);

void main() {
  test('removes all reminders when a user leaves', () async {
    final scheduler = FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(_testUserIdProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The app root watches it like this.
    container.listen<void>(
      followUpReminderCleanerProvider,
      (previous, next) {},
    );
    final user = container.read(_testUserIdProvider.notifier);

    Future<void> remindTomorrow(int id) => scheduler.schedule(
      id: id,
      title: 'Follow-up reminder',
      body: 'Proposal',
      when: DateTime.now().add(const Duration(days: 1)),
    );

    // First sign in: nobody left, so nothing is removed.
    await remindTomorrow(1);
    user.set('u1');
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 0);
    expect(scheduler.pending, isNotEmpty);

    // Sign out or a 401 answer: the old user left.
    user.set(null);
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 1);
    expect(scheduler.pending, isEmpty);

    // Another user signs in: nobody left. Then a third one replaces them.
    await remindTomorrow(2);
    user.set('u2');
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 1);
    expect(scheduler.pending, isNotEmpty);
    user.set('u3');
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 2);
    expect(scheduler.pending, isEmpty);
  });
}
