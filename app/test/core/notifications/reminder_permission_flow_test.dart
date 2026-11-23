import 'package:apply_track/core/notifications/notification_prefs_store.dart';
import 'package:apply_track/core/notifications/reminder_permission_flow.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_scheduler.dart';

void main() {
  late FakeNotificationScheduler scheduler;
  late InMemoryNotificationPrefsStore store;

  ReminderPermissionFlow flow({bool android = true}) => ReminderPermissionFlow(
    scheduler: scheduler,
    store: store,
    batteryHintApplies: android,
  );

  setUp(() {
    scheduler = FakeNotificationScheduler();
    store = InMemoryNotificationPrefsStore();
  });

  test('asks once, and not again after an app restart', () async {
    scheduler.permissionResult = false;

    expect(await flow().onDatePicked(), ReminderPermissionOutcome.denied);
    // A new flow with the same store is an app restart.
    expect(await flow().onDatePicked(), ReminderPermissionOutcome.alreadyAsked);
    expect(scheduler.permissionRequests, 1);
  });

  test('a platform without notifications is never asked', () async {
    scheduler.supported = false;

    expect(await flow().onDatePicked(), ReminderPermissionOutcome.unsupported);
    expect(await flow().takeBatteryHint(), isFalse);
    expect(scheduler.permissionRequests, 0);
  });

  test('the battery hint comes once, and only where it applies', () async {
    expect(await flow(android: false).takeBatteryHint(), isFalse);
    expect(await flow().takeBatteryHint(), isTrue);
    expect(await flow().takeBatteryHint(), isFalse);
  });
}
