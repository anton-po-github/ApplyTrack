import 'package:apply_track/core/notifications/notification_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The real scheduler (`flutter_local_notifications`) for Android and iOS.
///
/// It is a thin adapter. It uses inexact alarms, so the app needs no "exact
/// alarm" permission. The system can show a reminder a little late.
final class LocalNotificationScheduler implements NotificationScheduler {
  new({FlutterLocalNotificationsPlugin? plugin, this._now = DateTime.now})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'follow_up_reminders';
  static const String _channelName = 'Follow-up reminders';
  static const String _channelDescription =
      'Reminders to follow up on your proposals.';

  static const InitializationSettings _settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_notification'),
    // We ask for the permission later, in `requestPermission`.
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  Future<bool>? _initialization;

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) {
      return false;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!when.isAfter(_now())) {
      return false;
    }
    if (!await _ensureInitialized()) {
      return false;
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        // One exact moment. UTC is enough, so no device time zone is needed.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _plugin.cancel(id: id);
    } on Exception {
      // A reminder that stays is better than a crash.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _plugin.cancelAll();
    } on Exception {
      // A reminder that stays is better than a crash.
    }
  }

  /// The plugin must be initialized before use. We do it once, on first use.
  /// After a failure the next call tries again.
  Future<bool> _ensureInitialized() {
    final running = _initialization;
    if (running != null) {
      return running;
    }
    final start = _initialize();
    _initialization = start;
    return start.then((ok) {
      if (!ok) {
        _initialization = null;
      }
      return ok;
    });
  }

  Future<bool> _initialize() async {
    try {
      await _plugin.initialize(settings: _settings);
      return true;
    } on Exception {
      return false;
    }
  }
}
