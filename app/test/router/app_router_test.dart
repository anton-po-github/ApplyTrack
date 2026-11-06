import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/auth/ui/login_screen.dart';
import 'package:apply_track/features/auth/ui/signup_screen.dart';
import 'package:apply_track/features/auth/ui/startup_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_detail_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_form_screen.dart';
import 'package:apply_track/features/proposals/ui/proposal_list_screen.dart';
import 'package:apply_track/features/shell/app_shell.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../support/app_test_helpers.dart';
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
      expect(authRedirect(s, AppRoutes.stats), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.proposalNew), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.proposal(routeTestId)), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.startup), AppRoutes.login);
    });

    test('SignedIn leaves login, sign up and startup', () {
      const AuthState s = AuthSignedIn(testUser);
      expect(authRedirect(s, AppRoutes.login), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.signup), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.startup), AppRoutes.home);
      expect(authRedirect(s, AppRoutes.home), isNull);
      expect(authRedirect(s, AppRoutes.stats), isNull);
      expect(authRedirect(s, AppRoutes.proposalNew), isNull);
      expect(authRedirect(s, AppRoutes.proposal(routeTestId)), isNull);
    });
  });

  group('route paths', () {
    test('proposal paths are built from the id', () {
      expect(AppRoutes.proposal(routeTestId), '/proposals/$routeTestId');
      expect(
        AppRoutes.proposalEdit(routeTestId),
        '/proposals/$routeTestId/edit',
      );
    });

    test('an id cannot change the path', () {
      expect(AppRoutes.proposal('a/b?c'), '/proposals/a%2Fb%3Fc');
    });
  });

  group('guard in the app', () {
    testWidgets('no session: the app opens on login', (tester) async {
      await pumpApp(tester, FakeAuthRepository());

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('signed out cannot open a private page', (tester) async {
      await pumpApp(tester, FakeAuthRepository(), location: AppRoutes.stats);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('signed out cannot open a proposal link', (tester) async {
      await pumpApp(
        tester,
        FakeAuthRepository(),
        location: AppRoutes.proposal(routeTestId),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProposalDetailScreen), findsNothing);
    });

    testWidgets('saved session: the app opens on the shell', (tester) async {
      await pumpApp(tester, signedInRepo());

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(ProposalListScreen), findsOneWidget);
      expect(find.text('Anton'), findsOneWidget);
    });

    testWidgets('signed in cannot stay on login', (tester) async {
      await pumpApp(tester, signedInRepo(), location: AppRoutes.login);

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('unknown path shows the not found screen', (tester) async {
      await pumpApp(tester, signedInRepo());

      routerOf(tester, find.byType(AppShell)).go('/nope');
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

      expect(find.byType(AppShell), findsOneWidget);
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

      expect(find.byType(AppShell), findsOneWidget);
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
      expect(find.byType(AppShell), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(unauthorizedSignalProvider.notifier)
          .notify();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(repo.signOutCalls, 1);
    });
  });

  group('proposal routes', () {
    testWidgets('/proposals/new opens the new form, not a detail page', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());

      await goTo(tester, AppRoutes.proposalNew);

      expect(find.byType(ProposalFormScreen), findsOneWidget);
      expect(find.text('New proposal'), findsOneWidget);
      expect(find.text('Page not found'), findsNothing);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('a GUID opens the detail page', (tester) async {
      await pumpApp(tester, signedInRepo());

      await goTo(tester, AppRoutes.proposal(routeTestId));

      expect(find.byType(ProposalDetailScreen), findsOneWidget);
      expect(find.text('Proposal from server'), findsOneWidget);
    });

    testWidgets('a GUID opens the edit page', (tester) async {
      await pumpApp(tester, signedInRepo());

      await goTo(tester, AppRoutes.proposalEdit(routeTestId));

      expect(find.byType(ProposalFormScreen), findsOneWidget);
      expect(find.text('Edit proposal'), findsOneWidget);
    });

    testWidgets('an id that is not a GUID gives not found (detail)', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());

      await goTo(tester, '/proposals/not-a-guid');

      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text('No page for /proposals/not-a-guid'), findsOneWidget);
      expect(find.byType(ProposalDetailScreen), findsNothing);
    });

    testWidgets('an id that is not a GUID gives not found (edit)', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());

      await goTo(tester, '/proposals/12345/edit');

      expect(find.text('Page not found'), findsOneWidget);
      expect(find.byType(ProposalFormScreen), findsNothing);
    });

    testWidgets('Go home on the not found screen returns to the shell', (
      tester,
    ) async {
      await pumpApp(tester, signedInRepo());
      await goTo(tester, '/proposals/x');

      await tester.tap(find.text('Go home'));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('back from a page opened on top of the shell', (tester) async {
      await pumpApp(tester, signedInRepo());

      routerOf(tester, find.byType(AppShell)).push(AppRoutes.proposalNew);
      await tester.pumpAndSettle();
      expect(find.byType(ProposalFormScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
    });
  });
}
