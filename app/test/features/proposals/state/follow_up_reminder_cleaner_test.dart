import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/state/follow_up_reminder_cleaner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_test_helpers.dart';
import '../../../support/fake_notification_scheduler.dart';

void main() {
  late FakeNotificationScheduler scheduler;
  late FakeAuthRepository repo;
  late ProviderContainer container;

  AuthController auth() => container.read(authControllerProvider.notifier);

  Future<void> remindTomorrow(int id) => scheduler.schedule(
    id: id,
    title: 'Follow-up reminder',
    body: 'Proposal',
    when: DateTime.now().add(const Duration(days: 1)),
  );

  /// Starts the app like the real one: the cleaner is watched, and the saved
  /// session is checked. Reminders set before this call are "old" ones.
  Future<void> startApp(Session? session) async {
    repo = FakeAuthRepository(session: session);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        googleSignInProvider.overrideWithValue(FakeGoogleIdTokenProvider()),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);
    // The app root watches it like this. It also starts the auth controller.
    container.listen<void>(
      followUpReminderCleanerProvider,
      (previous, next) {},
    );
    await pumpEventQueue();
  }

  setUp(() {
    scheduler = FakeNotificationScheduler();
  });

  test('keeps reminders at app start, removes them at sign out', () async {
    await remindTomorrow(1);

    await startApp(validSession(user: testUser));
    expect(scheduler.cancelAllCalls, 0);
    expect(scheduler.pending, isNotEmpty);

    await auth().signOut();
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 1);
    expect(scheduler.pending, isEmpty);
  });

  test('a new sign in removes reminders left by an expired one', () async {
    await remindTomorrow(1);
    final expired = Session(
      token: 'tok',
      expiresAtUnixSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      user: testUser,
    );

    // Silent expiry at app start: nothing is removed yet.
    await startApp(expired);
    expect(scheduler.cancelAllCalls, 0);
    expect(scheduler.pending, isNotEmpty);

    // Another user signs in: the old reminders must go.
    repo.authOutcome = const AuthSuccess(
      UserProfile(id: 'u2', email: 'c@d.com', displayName: 'Other'),
    );
    await auth().signIn(email: 'c@d.com', password: 'secret-password');
    await pumpEventQueue();
    expect(scheduler.cancelAllCalls, 1);
    expect(scheduler.pending, isEmpty);
  });
}
