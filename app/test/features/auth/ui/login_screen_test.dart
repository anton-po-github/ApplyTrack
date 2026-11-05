import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';

import '../../../support/auth_test_helpers.dart';

import 'package:apply_track/features/auth/data/google_id_token_provider.dart';
import 'package:apply_track/features/auth/ui/auth_widgets.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  Future<void> pumpScreen(WidgetTester tester) =>
      pumpAuthScreen(tester, repo, const LoginScreen());

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'pw123456',
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty form shows errors and calls nothing', (tester) async {
    await pumpScreen(tester);

    await submit(tester);

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repo.signInCalls, 0);
  });

  testWidgets('valid form calls sign in', (tester) async {
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(repo.signInCalls, 1);
    expect(repo.lastArgs['email'], 'a@b.com');
    expect(repo.lastArgs['password'], 'pw123456');
  });

  testWidgets('wrong password shows one clear message', (tester) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.invalidCredentials,
      message: 'Wrong email or password.',
    );
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('429 shows the wait message', (tester) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.rateLimited,
      message: 'Too many tries. Please wait 12 seconds and try again.',
      retryAfterSeconds: 12,
    );
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.textContaining('wait 12 seconds'), findsOneWidget);
  });

  testWidgets('the button is disabled while loading', (tester) async {
    repo.authGate = Completer<AuthOutcome>();
    await pumpScreen(tester);

    await fill(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    repo.authGate!.complete(const AuthSuccess(testUser));
    await tester.pumpAndSettle();

    expect(repo.signInCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('Google button', () {
    Finder googleButton() =>
        find.widgetWithText(OutlinedButton, 'Continue with Google');

    testWidgets('is disabled when the build has no Google client ID', (
      tester,
    ) async {
      await pumpAuthScreen(
        tester,
        repo,
        const LoginScreen(),
        googleClientId: '',
      );

      expect(tester.widget<OutlinedButton>(googleButton()).onPressed, isNull);
    });

    testWidgets('sends the Google ID token to the server', (tester) async {
      await pumpAuthScreen(tester, repo, const LoginScreen());

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(repo.lastArgs['idToken'], 'google-id-token');
    });

    testWidgets('a closed dialog shows no error', (tester) async {
      final FakeGoogleIdTokenProvider google = FakeGoogleIdTokenProvider()
        ..result = const GoogleTokenCancelled();
      await pumpAuthScreen(tester, repo, const LoginScreen(), google: google);

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.byType(AuthErrorBanner), findsNothing);
      expect(repo.lastArgs, isEmpty);
    });

    testWidgets('a Google error shows one clear message', (tester) async {
      final FakeGoogleIdTokenProvider google = FakeGoogleIdTokenProvider()
        ..result = const GoogleTokenFailed('Google sign-in failed.');
      await pumpAuthScreen(tester, repo, const LoginScreen(), google: google);

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.text('Google sign-in failed.'), findsOneWidget);
    });

    testWidgets('a server rejection is shown', (tester) async {
      repo.authOutcome = const AuthFailure(
        kind: AuthFailureKind.googleEmailUnsupported,
        message: 'This Google email cannot be used.',
      );
      await pumpAuthScreen(tester, repo, const LoginScreen());

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.text('This Google email cannot be used.'), findsOneWidget);
    });
  });

  testWidgets('the password can be shown and hidden', (tester) async {
    await pumpScreen(tester);

    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Password'),
        matching: find.byType(EditableText),
      ),
    );

    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });
}
