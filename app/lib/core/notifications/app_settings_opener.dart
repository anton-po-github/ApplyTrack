import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the system settings page of this app (Android "App info").
/// The UI depends on this interface, so tests never touch a platform channel.
abstract interface class AppSettingsOpener {
  /// True when the settings page was opened. Never throws.
  Future<bool> open();
}

/// Talks to `MainActivity.kt`. No extra package is needed.
final class MethodChannelAppSettingsOpener implements AppSettingsOpener {
  const new({this._channel = const MethodChannel(channelName)});

  static const String channelName = 'com.antonpo.applytrack/app_settings';

  final MethodChannel _channel;

  @override
  Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on Exception {
      // A platform error, or a platform without this channel.
      return false;
    }
  }
}

final Provider<AppSettingsOpener> appSettingsOpenerProvider =
    Provider<AppSettingsOpener>(
      (ref) => const MethodChannelAppSettingsOpener(),
    );
