import 'package:apply_track/core/notifications/notification_scheduler.dart';

/// Used where we do not show notifications (the web). Nothing happens, and
/// `requestPermission` and `schedule` answer false.
final class NoopNotificationScheduler implements NotificationScheduler {
  const new();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async => false;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Stream<String> get taps => const Stream<String>.empty();

  @override
  Future<String?> launchPayload() async => null;
}
