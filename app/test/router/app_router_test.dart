import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/app.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:apply_track/features/auth/ui/startup_screen.dart';
import 'package:apply_track/features/counter/counter_screen.dart';
import 'package:apply_track/features/home/home_screen.dart';
import 'package:apply_track/router/app_router.dart';

import '../support/auth_test_helpers.dart';

void main() {
  group('authRedirect', () {
    test('Unknown and Unavailable wait on the startup screen', () {
      for (final AuthState s in <AuthState>[
        const AuthUnknown(),
        const AuthUnavailable(),
      ]) {
        expect(authRedirect(s, AppRoutes.home), AppRoutes.startup);
        expect(authRedirect(s, AppRoutes.login), AppRoutes.startup);
        expect(authRedirect(s, AppRoutes.startup), isNull);
      }
    });

    test('SignedOut can only see login and sign up', () {
      const AuthState s = AuthSignedOut();
      expect(authRedirect(s, AppRoutes.login), isNull);
      expect(authRedirect(s, AppRoutes.signup), isNull);
      expect(authRedirect(s, AppRoutes.home), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.counter), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.startup), AppRoutes.login);
    });

    test('SignedIn leaves login, sign up and startup', () {
      const AuthState s = AuthSignedIn(testUser);
      expect(authRedirect(s, AppRoutes.login), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.signup), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.startup), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.home), isNull);
      expect(authRedirect(s, AppRoutes.counter), isNull);
    });
  });

  group('guard in the app', () {
    Future<void> pumpApp(
      WidgetTester tester,
      FakeAuthRepository repo, {
      String location = AppRoutes.home,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            initialLocationProvider.overrideWithValue(location),
          ],
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();
    }

    FakeAuthRepository signedInRepo() =>
        FakeAuthRepository(session: validSession());

    testWidgets('no session: the app opens on login', (tester) async {
      await pumpApp(tester, FakeAuthRepository());

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('signed out cannot open a private page', (tester) async {
      await pumpApp(tester, FakeAuthRepository(), location: AppRoutes.counter);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CounterScreen), findsNothing);
    });

    testWidgets('saved session: the app opens on the main screen', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Anton'), findsOneWidget);
    });

    testWidgets('signed in: Counter opens and back returns home', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());

      await tester.tap(find.text('Counter'));
      await tester.pumpAndSettle();
      expect(find.byType(CounterScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('signed in cannot stay on login', (tester) async {
      await pumpApp(tester, signedInRepo(), location: AppRoutes.login);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('unknown path shows the not found screen', (tester) async {
      await pumpApp(tester, signedInRepo());
      expect(find.byType(HomeScreen), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
          .read(appRouterProvider)
          .go('/nope');
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text('No page for /nope'), findsOneWidget);
    });
    testWidgets('no network at start: Retry brings the user in', (
      tester,
    ) async {
      final FakeAuthRepository repo = signedInRepo()
        ..meOutcome = const AuthFailure(
          kind: AuthFailureKind.network,
          message: 'No connection.',
        );
      await pumpApp(tester, repo);

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      repo.meOutcome = const AuthSuccess(testUser);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('login and sign up link to each other', (tester) async {
      await pumpApp(tester, FakeAuthRepository());

      await tester.tap(find.text('No account? Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);

      await tester.tap(find.text('Have an account? Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('sign in, then sign out, returns to login', (tester) async {
      await pumpApp(tester, FakeAuthRepository());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'pw123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Anton'), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a 401 from the server sends the user to login', (
      tester,
    ) async {
      final FakeAuthRepository repo = signedInRepo();
      await pumpApp(tester, repo);
      expect(find.byType(HomeScreen), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
          .read(unauthorizedSignalProvider.notifier)
          .notify();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(repo.signOutCalls, 1);
    });
  });
}
