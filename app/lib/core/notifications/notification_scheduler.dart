/// Shows reminders at a chosen time, outside the app.
/// The UI and the state code depend on this interface, so tests never touch
/// a plugin.
///
/// No method throws. A failure becomes `false`, or is ignored.
abstract interface class NotificationScheduler {
  /// True on a platform that can show scheduled notifications (Android and
  /// iOS). When false, the app must not ask for permission or show hints.
  bool get isSupported;

  /// Asks the user to allow notifications. True when they are allowed.
  /// On a platform without notifications, it is always false.
  Future<bool> requestPermission();

  /// Schedules one notification for [when]. A new call with the same [id]
  /// replaces the old one. True when the system accepted it.
  /// A [when] that is not in the future is not accepted (false).
  ///
  /// [payload] comes back in [taps] (or in [launchPayload]) when the user
  /// taps the notification. It is plain text. Treat it as untrusted input
  /// when you read it.
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  });

  /// Removes the notification with [id]. A missing id is not an error.
  Future<void> cancel(int id);

  /// Removes every notification of this app.
  Future<void> cancelAll();

  /// The payloads of notifications the user taps while the app is running
  /// (in front or in the background). A notification without a payload gives
  /// nothing. A tap that happens before anyone listens is not replayed here:
  /// for the start of the app, use [launchPayload].
  Stream<String> get taps;

  /// The payload of the notification whose tap started the app, or null.
  /// Call it once, at app start. It never throws.
  Future<String?> launchPayload();
}
