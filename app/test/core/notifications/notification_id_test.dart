import 'package:apply_track/core/notifications/notification_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // If this number changes, reminders that are already scheduled can no
  // longer be cancelled. Do not "fix" the expected value.
  test('a GUID always gives the same id, in any letter case', () {
    const guid = '0190a1b2-0000-7000-8000-000000000001';

    expect(notificationIdFor(guid), 467634185);
    expect(notificationIdFor(guid.toUpperCase()), 467634185);
  });
}
