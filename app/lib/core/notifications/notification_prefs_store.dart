import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Two small facts about this device that must survive an app restart:
/// did we ask for the notification permission, and did we show the battery
/// hint. They are per device, not per user, so a sign out does not clear them.
///
/// No method throws. A storage failure is hidden: the answer is kept in
/// memory for the rest of the run.
abstract interface class NotificationPrefsStore {
  Future<bool> wasAsked();

  Future<void> markAsked();

  Future<bool> wasBatteryHintShown();

  Future<void> markBatteryHintShown();
}

/// For tests (and fakes). Nothing is saved to disk.
final class InMemoryNotificationPrefsStore implements NotificationPrefsStore {
  new({this._asked = false, this._batteryHintShown = false});

  bool _asked;
  bool _batteryHintShown;

  @override
  Future<bool> wasAsked() async => _asked;

  @override
  Future<void> markAsked() async => _asked = true;

  @override
  Future<bool> wasBatteryHintShown() async => _batteryHintShown;

  @override
  Future<void> markBatteryHintShown() async => _batteryHintShown = true;
}

/// Android Keystore / iOS Keychain. On web it uses `localStorage`.
/// It is not a secret, but this package is already in the app.
final class SecureNotificationPrefsStore implements NotificationPrefsStore {
  new({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String askedKey = 'applytrack.notifications.asked';
  static const String batteryHintKey = 'applytrack.notifications.battery';

  final FlutterSecureStorage _storage;
  late final _Flag _asked = _Flag(_storage, askedKey);
  late final _Flag _batteryHint = _Flag(_storage, batteryHintKey);

  @override
  Future<bool> wasAsked() => _asked.read();

  @override
  Future<void> markAsked() => _asked.set();

  @override
  Future<bool> wasBatteryHintShown() => _batteryHint.read();

  @override
  Future<void> markBatteryHintShown() => _batteryHint.set();
}

/// One yes/no fact in secure storage, with a copy in memory.
final class _Flag {
  new(this._storage, this._key);

  final FlutterSecureStorage _storage;
  final String _key;
  bool? _cached;

  Future<bool> read() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }
    try {
      final value = await _storage.read(key: _key) == 'true';
      _cached = value;
      return value;
    } on Exception {
      return false;
    }
  }

  Future<void> set() async {
    // The memory copy is set first, so a storage failure does not repeat it.
    _cached = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } on Exception {
      // Kept in memory for this run only.
    }
  }
}

final Provider<NotificationPrefsStore> notificationPrefsStoreProvider =
    Provider<NotificationPrefsStore>((ref) => SecureNotificationPrefsStore());
