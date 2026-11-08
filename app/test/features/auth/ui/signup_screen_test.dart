import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/auth_test_helpers.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  Future<void> pumpScreen(WidgetTester tester) =>
      pumpAuthScreen(tester, repo, const SignupScreen());

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Anton');
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
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty form shows errors and calls nothing', (tester) async {
    await pumpScreen(tester);

    await submit(tester);

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repo.signUpCalls, 0);
  });

  testWidgets('a short password is stopped on the device', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'A');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    await submit(tester);

    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(repo.signUpCalls, 0);
  });

  testWidgets('valid form calls sign up with the typed values', (tester) async {
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(repo.signUpCalls, 1);
    expect(repo.lastArgs, <String, String>{
      'email': 'a@b.com',
      'password': 'pw123456',
      'displayName': 'Anton',
    });
  });

  testWidgets('server field errors show under the input', (tester) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.validation,
      message: 'Please fix the fields.',
      fields: <String, String>{'displayName': 'Name is not allowed.'},
    );
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('Name is not allowed.'), findsOneWidget);
    // Field errors replace the general message.
    expect(find.text('Please fix the fields.'), findsNothing);
  });

  testWidgets('email taken shows under the email input', (tester) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.emailTaken,
      message: 'This email is already used.',
      fields: <String, String>{'email': 'This email is already used.'},
    );
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('This email is already used.'), findsOneWidget);
  });

  testWidgets('typing in a field clears its server error', (tester) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.emailTaken,
      message: 'This email is already used.',
      fields: <String, String>{'email': 'This email is already used.'},
    );
    await pumpScreen(tester);
    await fill(tester);
    await submit(tester);
    expect(find.text('This email is already used.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'other@b.com',
    );
    await tester.pump();

    expect(find.text('This email is already used.'), findsNothing);
  });

  testWidgets('an error without fields shows one general message', (
    tester,
  ) async {
    repo.authOutcome = const AuthFailure(
      kind: AuthFailureKind.network,
      message: 'No connection. Check your internet and try again.',
    );
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.textContaining('No connection'), findsOneWidget);
  });
}
