import 'dart:async';

import 'package:apply_track/features/proposals/state/follow_up_reminder_service.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Removes every phone reminder when a user leaves: sign out, a 401 answer,
/// or another user who signs in. The next person on this device must not get
/// the reminders of the old user.
///
/// It listens to [currentUserIdProvider], like the saved list cleaner. The
/// app root watches this provider, so it is alive for the whole run.
///
/// The first sign in (old id is null) removes nothing. The new user gets
/// their reminders from the first page of the list.
final Provider<void> followUpReminderCleanerProvider = Provider<void>((ref) {
  ref.listen<String?>(currentUserIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      unawaited(ref.read(followUpReminderServiceProvider).clearAll());
    }
  });
});
