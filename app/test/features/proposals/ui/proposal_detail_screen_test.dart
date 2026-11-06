import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/ui/proposal_detail_screen.dart';
import 'package:apply_track/router/app_router.dart';

import '../../../support/app_test_helpers.dart';
import '../../../support/fake_external_link_opener.dart';
import '../../../support/fake_proposals_api.dart';

void main() {
  const String dash = '\u2014';

  late FakeProposalsApi api;
  late FakeExternalLinkOpener opener;

  /// What `GET` gives back. Each test can change it before it opens the page.
  late Proposal served;

  Proposal proposalWith({
    String title = 'Server title',
    ProposalStatus status = ProposalStatus.draft,
    String? company,
    double? budget,
    CalendarDate? followUp,
    String? link,
    String? notes,
  }) => Proposal(
    id: routeTestId,
    title: title,
    company: company,
    platform: ProposalPlatform.email,
    status: status,
    budget: budget,
    followUpDate: followUp,
    link: link,
    notes: notes,
    createdAtMs: 1,
    updatedAtMs: 1,
  );

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Column(
              children: <Widget>[
                const Text('HOME'),
                TextButton(
                  key: const Key('open-detail'),
                  onPressed: () =>
                      context.push(AppRoutes.proposal(routeTestId)),
                  child: const Text('open detail'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/proposals/:id',
          builder: (BuildContext context, GoRouterState state) =>
              ProposalDetailScreen(proposalId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/proposals/:id/edit',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            appBar: AppBar(title: const Text('EDIT PAGE')),
            body: TextButton(
              key: const Key('edit-done'),
              onPressed: () => context.pop(),
              child: const Text('done'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proposalsApiProvider.overrideWithValue(api),
          externalLinkOpenerProvider.overrideWithValue(opener),
          currentUserIdProvider.overrideWithValue('u1'),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 6, 10)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('open-detail')));
    await tester.pumpAndSettle();
  }

  Finder key(String name) => find.byKey(Key(name));

  String textOf(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  setUp(() {
    api = FakeProposalsApi();
    opener = FakeExternalLinkOpener();
    served = proposalWith();
    api.getHandler = (String id) async => ApiOk<Proposal>(served);
  });

  group('loading', () {
    testWidgets('shows a spinner first, then the proposal', (tester) async {
      final Completer<ApiResult<Proposal>> gate =
          Completer<ApiResult<Proposal>>();
      api.getHandler = (String id) => gate.future;
      await pumpHome(tester);

      await tester.tap(key('open-detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(key('detail-loading'), findsOneWidget);
      expect(api.getIds, <String>[routeTestId]);

      gate.complete(ApiOk<Proposal>(served));
      await tester.pumpAndSettle();

      expect(key('detail-loading'), findsNothing);
      expect(textOf(tester, 'detail-title'), 'Server title');
    });

    testWidgets('shows all fields', (tester) async {
      served = proposalWith(
        status: ProposalStatus.viewed,
        company: 'Acme',
        budget: 1234.5,
        followUp: CalendarDate(2026, 12, 1),
        link: 'https://acme.io/job',
        notes: 'Line one\nLine two',
      );
      await openDetail(tester);

      expect(textOf(tester, 'detail-title'), 'Server title');
      expect(
        find.descendant(
          of: key('detail-status'),
          matching: find.text('Viewed'),
        ),
        findsOneWidget,
      );
      expect(textOf(tester, 'detail-company'), 'Acme');
      expect(textOf(tester, 'detail-platform'), 'Email');
      expect(textOf(tester, 'detail-budget'), r'$1,234.50');
      expect(textOf(tester, 'detail-follow-up'), '1 Dec 2026');
      expect(find.text('https://acme.io/job'), findsOneWidget);
      expect(textOf(tester, 'detail-notes'), 'Line one\nLine two');
      expect(key('detail-created'), findsOneWidget);
      expect(key('detail-updated'), findsOneWidget);
    });

    testWidgets('a missing field shows a dash', (tester) async {
      await openDetail(tester);

      expect(textOf(tester, 'detail-company'), dash);
      expect(textOf(tester, 'detail-budget'), dash);
      expect(textOf(tester, 'detail-follow-up'), dash);
      expect(textOf(tester, 'detail-link-text'), dash);
      expect(textOf(tester, 'detail-notes'), dash);
    });

    testWidgets('not found shows a message and Back returns', (tester) async {
      api.getHandler = (String id) async => const ApiErr<Proposal>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found'),
      );
      await openDetail(tester);

      expect(key('detail-not-found'), findsOneWidget);
      expect(key('detail-edit'), findsNothing);
      expect(key('detail-delete'), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('an error shows Retry, and Retry loads again', (tester) async {
      api.getHandler = (String id) async =>
          const ApiErr<Proposal>(ApiError.network());
      await openDetail(tester);

      expect(key('detail-load-error'), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );

      api.getHandler = (String id) async => ApiOk<Proposal>(served);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(key('detail-load-error'), findsNothing);
      expect(textOf(tester, 'detail-title'), 'Server title');
      expect(api.getIds, hasLength(2));
    });
  });

  group('follow-up warning', () {
    testWidgets('shown for Sent with a date that is today or earlier', (
      tester,
    ) async {
      served = proposalWith(
        status: ProposalStatus.sent,
        followUp: CalendarDate(2026, 11, 6),
      );
      await openDetail(tester);

      expect(key('detail-follow-up-due'), findsOneWidget);
    });

    testWidgets('not shown for a future date', (tester) async {
      served = proposalWith(
        status: ProposalStatus.sent,
        followUp: CalendarDate(2026, 11, 7),
      );
      await openDetail(tester);

      expect(key('detail-follow-up-due'), findsNothing);
      expect(key('detail-follow-up'), findsOneWidget);
    });

    testWidgets('not shown for a status that needs no follow-up', (
      tester,
    ) async {
      served = proposalWith(
        status: ProposalStatus.won,
        followUp: CalendarDate(2026, 1, 1),
      );
      await openDetail(tester);

      expect(key('detail-follow-up-due'), findsNothing);
    });
  });

  group('link', () {
    testWidgets('a tap opens the link in the browser', (tester) async {
      served = proposalWith(link: 'https://acme.io/job');
      await openDetail(tester);

      await tester.tap(key('detail-link'));
      await tester.pumpAndSettle();

      expect(opener.opened, <Uri>[Uri.parse('https://acme.io/job')]);
      expect(find.text('Could not open the link.'), findsNothing);
    });

    testWidgets('a link that cannot be opened shows a message', (tester) async {
      opener.result = false;
      served = proposalWith(link: 'https://acme.io/job');
      await openDetail(tester);

      await tester.tap(key('detail-link'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the link.'), findsOneWidget);
    });

    testWidgets('an unsafe link is plain text and cannot be tapped', (
      tester,
    ) async {
      served = proposalWith(link: 'javascript:alert(1)');
      await openDetail(tester);

      expect(key('detail-link'), findsNothing);
      expect(textOf(tester, 'detail-link-text'), 'javascript:alert(1)');
      expect(opener.opened, isEmpty);
    });
  });

  group('status flow', () {
    testWidgets('Draft offers only Sent', (tester) async {
      await openDetail(tester);

      expect(key('advance-sent'), findsOneWidget);
      expect(find.text('Mark as Sent'), findsOneWidget);
      expect(key('advance-viewed'), findsNothing);
      expect(key('advance-won'), findsNothing);
    });

    testWidgets('Interview offers Won and Lost', (tester) async {
      served = proposalWith(status: ProposalStatus.interview);
      await openDetail(tester);

      expect(key('advance-won'), findsOneWidget);
      expect(key('advance-lost'), findsOneWidget);
    });

    testWidgets('Won offers nothing', (tester) async {
      served = proposalWith(status: ProposalStatus.won);
      await openDetail(tester);

      expect(find.text('Next stage'), findsNothing);
      expect(key('detail-edit'), findsOneWidget);
    });

    testWidgets('Lost offers nothing', (tester) async {
      served = proposalWith(status: ProposalStatus.lost);
      await openDetail(tester);

      expect(find.text('Next stage'), findsNothing);
      expect(key('detail-edit'), findsOneWidget);
    });

    testWidgets('a tap sends a full PUT and shows the server answer', (
      tester,
    ) async {
      served = proposalWith(
        company: 'Acme',
        budget: 50,
        followUp: CalendarDate(2026, 12, 1),
        link: 'https://acme.io',
        notes: 'Keep me',
      );
      // The server may change other things too. The screen must show this.
      api.updateHandler = (String id, ProposalDraft draft) async =>
          ApiOk<Proposal>(
            proposalWith(
              title: 'Title from the server',
              status: ProposalStatus.sent,
              company: 'Acme',
            ),
          );
      await openDetail(tester);

      await tester.tap(key('advance-sent'));
      await tester.pumpAndSettle();

      expect(api.updateIds, <String>[routeTestId]);
      expect(
        api.updateDrafts.single,
        ProposalDraft.fromProposal(served).withStatus(ProposalStatus.sent),
      );
      final Map<String, Object?> body = api.updateDrafts.single.toJson();
      expect(body, hasLength(8));
      expect(body['status'], ProposalStatus.sent.apiValue);
      expect(body['notes'], 'Keep me');

      expect(textOf(tester, 'detail-title'), 'Title from the server');
      expect(
        find.descendant(of: key('detail-status'), matching: find.text('Sent')),
        findsOneWidget,
      );
      expect(key('advance-viewed'), findsOneWidget);
      expect(key('advance-sent'), findsNothing);
    });

    testWidgets('two fast taps send one request', (tester) async {
      final Completer<ApiResult<Proposal>> gate =
          Completer<ApiResult<Proposal>>();
      api.updateHandler = (String id, ProposalDraft draft) => gate.future;
      await openDetail(tester);

      await tester.tap(key('advance-sent'));
      await tester.tap(key('advance-sent'));
      await tester.pump();

      expect(api.updateIds, hasLength(1));
      expect(key('detail-busy'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('advance-sent')).onPressed,
        isNull,
      );

      gate.complete(ApiOk<Proposal>(proposalWith(status: ProposalStatus.sent)));
      await tester.pumpAndSettle();

      expect(api.updateIds, hasLength(1));
      expect(key('detail-busy'), findsNothing);
    });

    testWidgets('an error shows a banner and keeps the old status', (
      tester,
    ) async {
      api.updateHandler = (String id, ProposalDraft draft) async =>
          const ApiErr<Proposal>(
            ApiError(
              code: ApiErrorCodes.rateLimited,
              message: 'Slow down',
              retryAfterSeconds: 5,
            ),
          );
      await openDetail(tester);

      await tester.tap(key('advance-sent'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: key('detail-error-banner'),
          matching: find.text('Too many requests. Try again in 5 seconds.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key('detail-status'), matching: find.text('Draft')),
        findsOneWidget,
      );
      // No auto retry, and the user can try again.
      expect(api.updateIds, hasLength(1));
      expect(
        tester.widget<FilledButton>(key('advance-sent')).onPressed,
        isNotNull,
      );
    });

    testWidgets('the next tap clears the old error', (tester) async {
      api.updateHandler = (String id, ProposalDraft draft) async =>
          const ApiErr<Proposal>(ApiError.network());
      await openDetail(tester);
      await tester.tap(key('advance-sent'));
      await tester.pumpAndSettle();
      expect(key('detail-error-banner'), findsOneWidget);

      api.updateHandler = (String id, ProposalDraft draft) async =>
          ApiOk<Proposal>(proposalWith(status: ProposalStatus.sent));
      await tester.tap(key('advance-sent'));
      await tester.pumpAndSettle();

      expect(key('detail-error-banner'), findsNothing);
    });

    testWidgets('not found on update shows the not found message', (
      tester,
    ) async {
      api.updateHandler = (String id, ProposalDraft draft) async =>
          const ApiErr<Proposal>(
            ApiError(code: ApiErrorCodes.notFound, message: 'Not found'),
          );
      await openDetail(tester);

      await tester.tap(key('advance-sent'));
      await tester.pumpAndSettle();

      expect(key('detail-not-found'), findsOneWidget);
      expect(key('detail-edit'), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('opens the form, and loads the proposal again on return', (
      tester,
    ) async {
      await openDetail(tester);
      expect(api.getIds, hasLength(1));

      served = proposalWith(title: 'Edited title');
      await tester.tap(key('detail-edit'));
      await tester.pumpAndSettle();
      expect(find.text('EDIT PAGE'), findsOneWidget);

      await tester.tap(key('edit-done'));
      await tester.pumpAndSettle();

      expect(api.getIds, hasLength(2));
      expect(textOf(tester, 'detail-title'), 'Edited title');
    });

    testWidgets('a failed reload keeps the old data on screen', (tester) async {
      await openDetail(tester);

      api.getHandler = (String id) async =>
          const ApiErr<Proposal>(ApiError.network());
      await tester.tap(key('detail-edit'));
      await tester.pumpAndSettle();
      await tester.tap(key('edit-done'));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'detail-title'), 'Server title');
      expect(key('detail-load-error'), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('Cancel sends nothing', (tester) async {
      await openDetail(tester);

      await tester.tap(key('detail-delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete proposal?'), findsOneWidget);

      await tester.tap(key('delete-cancel'));
      await tester.pumpAndSettle();

      expect(api.deleteIds, isEmpty);
      expect(key('detail-title'), findsOneWidget);
    });

    testWidgets('Confirm deletes, goes back and says so', (tester) async {
      await openDetail(tester);

      await tester.tap(key('detail-delete'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-confirm'));
      await tester.pumpAndSettle();

      expect(api.deleteIds, <String>[routeTestId]);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Proposal deleted.'), findsOneWidget);
    });

    testWidgets('not found counts as already deleted', (tester) async {
      api.deleteHandler = (String id) async => const ApiErr<void>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found'),
      );
      await openDetail(tester);

      await tester.tap(key('detail-delete'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-confirm'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('This proposal was already deleted.'), findsOneWidget);
    });

    testWidgets('another error keeps the screen and shows a banner', (
      tester,
    ) async {
      api.deleteHandler = (String id) async => const ApiErr<void>(
        ApiError(code: ApiErrorCodes.serverError, message: 'Boom'),
      );
      await openDetail(tester);

      await tester.tap(key('detail-delete'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-confirm'));
      await tester.pumpAndSettle();

      expect(key('detail-title'), findsOneWidget);
      expect(
        find.descendant(
          of: key('detail-error-banner'),
          matching: find.text(
            'The server has a problem. Try again in a moment.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('HOME'), findsNothing);
      expect(
        tester.widget<IconButton>(key('detail-delete')).onPressed,
        isNotNull,
      );
    });
  });
}
