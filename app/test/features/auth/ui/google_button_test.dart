import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/data/google_id_token_provider.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/ui/google_button.dart';

import '../../../support/auth_test_helpers.dart';

void main() {
  late FakeAuthRepository repo;
  late FakeGoogleIdTokenProvider google;
  AuthOutcome? lastOutcome;
  int started = 0;

  setUp(() {
    repo = FakeAuthRepository();
    google = FakeGoogleIdTokenProvider();
    lastOutcome = null;
    started = 0;
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    String clientId = 'test-client-id',
  }) => pumpAuthScreen(
    tester,
    repo,
    Scaffold(
      body: GoogleSignInButton(
        onStarted: () => started++,
        onOutcome: (AuthOutcome outcome) => lastOutcome = outcome,
      ),
    ),
    google: google,
    googleClientId: clientId,
  );

  Finder ownButton() =>
      find.widgetWithText(OutlinedButton, 'Continue with Google');
  Finder renderedArea() => find.byKey(GoogleSignInButton.renderedButtonKey);

  group('mobile', () {
    testWidgets('tap runs the Google dialog and signs in', (tester) async {
      await pumpButton(tester);

      await tester.tap(ownButton());
      await tester.pumpAndSettle();

      expect(started, 1);
      expect(google.getCalls, 1);
      expect(repo.lastArgs['idToken'], 'google-id-token');
      expect(lastOutcome, isA<AuthSuccess>());
      expect(renderedArea(), findsNothing);
    });

    testWidgets('is disabled without a client ID', (tester) async {
      await pumpButton(tester, clientId: '');

      expect(tester.widget<OutlinedButton>(ownButton()).onPressed, isNull);
    });
  });

  group('web (Google draws the button)', () {
    setUp(() => google.renderedButton = true);

    testWidgets('shows the rendered button after prepare', (tester) async {
      await pumpButton(tester);

      expect(google.prepareCalls, 1);
      expect(renderedArea(), findsOneWidget);
      expect(ownButton(), findsNothing);
    });

    testWidgets('a token from the stream signs the user in', (tester) async {
      await pumpButton(tester);

      google.emit(const GoogleTokenOk('web-token'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(started, 1);
      expect(repo.lastArgs['idToken'], 'web-token');
      expect(lastOutcome, isA<AuthSuccess>());
    });

    testWidgets('a cancelled event calls no server', (tester) async {
      await pumpButton(tester);

      google.emit(const GoogleTokenCancelled());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.lastArgs, isEmpty);
      expect((lastOutcome! as AuthFailure).kind, AuthFailureKind.cancelled);
    });

    testWidgets('a Google error is passed on with its message', (tester) async {
      await pumpButton(tester);

      google.emit(const GoogleTokenFailed('Google sign-in failed.'));
      await tester.pump();
      await tester.pumpAndSettle();

      final AuthFailure f = lastOutcome! as AuthFailure;
      expect(f.kind, AuthFailureKind.googleSignIn);
      expect(f.message, 'Google sign-in failed.');
      expect(repo.lastArgs, isEmpty);
    });

    testWidgets('a plugin that cannot start shows a disabled button', (
      tester,
    ) async {
      google.prepareResult = false;
      await pumpButton(tester);

      expect(renderedArea(), findsNothing);
      expect(tester.widget<OutlinedButton>(ownButton()).onPressed, isNull);
    });

    testWidgets('without a client ID the plugin is not started', (
      tester,
    ) async {
      await pumpButton(tester, clientId: '');

      expect(google.prepareCalls, 0);
      expect(renderedArea(), findsNothing);
      expect(tester.widget<OutlinedButton>(ownButton()).onPressed, isNull);
    });
  });
}
