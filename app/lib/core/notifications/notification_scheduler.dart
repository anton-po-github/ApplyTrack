/// Shows reminders at a chosen time, outside the app.
/// The UI and the state code depend on this interface, so tests never touch
/// a plugin.
///
/// No method throws. A failure becomes `false`, or is ignored.
abstract interface class NotificationScheduler {
  /// Asks the user to allow notifications. True when they are allowed.
  /// On a platform without notifications, it is always false.
  Future<bool> requestPermission();

  /// Schedules one notification for [when]. A new call with the same [id]
  /// replaces the old one. True when the system accepted it.
  /// A [when] that is not in the future is not accepted (false).
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });

  /// Removes the notification with [id]. A missing id is not an error.
  Future<void> cancel(int id);

  /// Removes every notification of this app.
  Future<void> cancelAll();
}
