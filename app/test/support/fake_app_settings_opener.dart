import 'package:apply_track/core/notifications/app_settings_opener.dart';

/// A fake [AppSettingsOpener]. It counts the calls and answers [result].
final class FakeAppSettingsOpener implements AppSettingsOpener {
  int openCalls = 0;
  bool result = true;

  @override
  Future<bool> open() async {
    openCalls++;
    return result;
  }
}
