import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phase2_widgets/features/signup/signup_gateway.dart';
import 'package:phase2_widgets/features/signup/signup_providers.dart';
import 'package:phase2_widgets/features/signup/signup_screen.dart';

final class FakeSignupGateway implements SignupGateway {
  FakeSignupGateway(this.result);

  final SignupResult result;
  final List<SignupData> received = <SignupData>[];

  @override
  Future<SignupResult> submit(SignupData data) async {
    received.add(data);
    return result;
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeSignupGateway gateway,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signupGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    required String name,
    required String email,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty form shows errors and sends nothing', (
    WidgetTester tester,
  ) async {
    final FakeSignupGateway gateway = FakeSignupGateway(const SignupAccepted());
    await pumpScreen(tester, gateway);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(gateway.received, isEmpty);
  });

  testWidgets('valid form sends trimmed data and shows success', (
    WidgetTester tester,
  ) async {
    final FakeSignupGateway gateway = FakeSignupGateway(const SignupAccepted());
    await pumpScreen(tester, gateway);

    await fillAndSubmit(tester, name: ' Anton ', email: 'anton@example.com');

    expect(gateway.received.single.name, 'Anton');
    expect(gateway.received.single.email, 'anton@example.com');
    expect(find.text('Account created'), findsOneWidget);
  });

  testWidgets('server rejection is shown to the user', (
    WidgetTester tester,
  ) async {
    final FakeSignupGateway gateway = FakeSignupGateway(
      const SignupRejected('This email is already used'),
    );
    await pumpScreen(tester, gateway);

    await fillAndSubmit(tester, name: 'Anton', email: 'taken@example.com');

    expect(find.text('This email is already used'), findsOneWidget);
  });
}
