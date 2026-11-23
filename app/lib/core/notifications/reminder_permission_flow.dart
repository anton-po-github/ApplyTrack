import 'package:apply_track/core/notifications/notification_prefs_store.dart';
import 'package:apply_track/core/notifications/notification_scheduler.dart';
import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What happened when the user picked a follow-up date.
enum ReminderPermissionOutcome {
  /// This platform shows no notifications (the web). Show nothing.
  unsupported,

  /// We asked before. Do not ask again, and show nothing.
  alreadyAsked,

  /// The user allowed notifications just now.
  granted,

  /// The user did not allow notifications just now. Show the hint once.
  denied,
}

/// Decides WHEN to ask for the notification permission, and when to show the
/// battery hint. It has no UI. The form shows what it returns.
///
/// We ask only once, at the first date the user picks. The answer is saved
/// before the system dialog opens, so a closed app or a double tap never
/// asks twice. Later the user can change the setting in the phone settings.
final class ReminderPermissionFlow {
  new({
    required this._scheduler,
    required this._store,
    required this._batteryHintApplies,
  });

  final NotificationScheduler _scheduler;
  final NotificationPrefsStore _store;
  final bool _batteryHintApplies;
  bool _asking = false;

  /// Call it after the user picks a follow-up date.
  Future<ReminderPermissionOutcome> onDatePicked() async {
    if (!_scheduler.isSupported) {
      return ReminderPermissionOutcome.unsupported;
    }
    if (_asking || await _store.wasAsked()) {
      return ReminderPermissionOutcome.alreadyAsked;
    }
    _asking = true;
    try {
      await _store.markAsked();
      final allowed = await _scheduler.requestPermission();
      return allowed
          ? ReminderPermissionOutcome.granted
          : ReminderPermissionOutcome.denied;
    } finally {
      _asking = false;
    }
  }

  /// True only the first time, and only where the hint applies (Android).
  /// The hint is then marked as shown.
  Future<bool> takeBatteryHint() async {
    if (!_batteryHintApplies || !_scheduler.isSupported) {
      return false;
    }
    if (await _store.wasBatteryHintShown()) {
      return false;
    }
    await _store.markBatteryHintShown();
    return true;
  }
}

final Provider<ReminderPermissionFlow> reminderPermissionFlowProvider =
    Provider<ReminderPermissionFlow>(
      (ref) => ReminderPermissionFlow(
        scheduler: ref.read(notificationSchedulerProvider),
        store: ref.read(notificationPrefsStoreProvider),
        batteryHintApplies:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      ),
    );
