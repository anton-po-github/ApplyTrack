import 'dart:async';

import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/proposals/state/follow_up_reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Removes every phone reminder when the next person must not get them.
///
/// It clears in two cases:
/// - A signed-in user leaves (sign out, a 401 answer) or another user takes
///   their place.
/// - A fresh sign in happens (the state was signed out). A session can
///   expire silently at app start. Then nobody "left" in a way we can see,
///   and the reminders of that user are still on the phone.
///
/// A start with a saved session goes from unknown to signed in. It clears
/// nothing, so reminders survive an app restart and an offline start. After a
/// fresh sign in, the first page of the list sets the reminders again.
///
/// The app root watches this provider, so it is alive for the whole run.
final Provider<void> followUpReminderCleanerProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (_shouldClear(previous, next)) {
      unawaited(ref.read(followUpReminderServiceProvider).clearAll());
    }
  });
});

bool _shouldClear(AuthState? previous, AuthState next) {
  if (previous is AuthSignedIn) {
    return next is! AuthSignedIn || next.user.id != previous.user.id;
  }
  return previous is AuthSignedOut && next is AuthSignedIn;
}
