import 'dart:async';

import 'package:apply_track/core/notifications/notification_scheduler.dart';

/// A reminder, as the fake saw it.
typedef FakeReminder = ({
  int id,
  String title,
  String body,
  DateTime when,
  String? payload,
});

/// A fake [NotificationScheduler] in memory. It follows the same rules as the
/// real one: the same id replaces the old reminder, and a time that is not in
/// the future is not accepted.
final class FakeNotificationScheduler implements NotificationScheduler {
  new({this._now = DateTime.now});

  final DateTime Function() _now;
  final Map<int, FakeReminder> _pending = <int, FakeReminder>{};
  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// What `isSupported` answers.
  bool supported = true;

  /// What `requestPermission` answers.
  bool permissionResult = true;

  /// What `schedule` answers. When false, nothing is saved.
  bool scheduleResult = true;

  /// What `launchPayload` answers (a tap that started the app).
  String? launchPayloadResult;

  /// How many times `requestPermission` was called.
  int permissionRequests = 0;

  /// Every id given to `cancel`, in call order.
  final List<int> cancelledIds = <int>[];

  /// How many times `cancelAll` was called.
  int cancelAllCalls = 0;

  /// The reminders that are waiting now.
  List<FakeReminder> get pending =>
      List<FakeReminder>.unmodifiable(_pending.values);

  /// Acts like a user who taps a notification while the app is running.
  void replayTap(String payload) => _taps.add(payload);

  @override
  bool get isSupported => supported;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async => launchPayloadResult;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionResult;
  }

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (!scheduleResult || !when.isAfter(_now())) {
      return false;
    }
    _pending[id] = (
      id: id,
      title: title,
      body: body,
      when: when,
      payload: payload,
    );
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    _pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    _pending.clear();
  }
}
