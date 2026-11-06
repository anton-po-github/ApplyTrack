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
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/ui/proposal_list_screen.dart';
import 'package:apply_track/router/app_router.dart';

import '../../../support/fake_debounce_timers.dart';
import '../../../support/fake_proposals_api.dart';
import '../../../support/proposal_fixtures.dart';

typedef Gate = Completer<ApiResult<ProposalPage>>;

void main() {
  late FakeProposalsApi api;
  late FakeDebounceTimers timers;

  // "Today" in all tests: 6 Nov 2026.
  final DateTime now = DateTime(2026, 11, 6, 10);

  Future<void> pumpList(
    WidgetTester tester, {
    Size size = const Size(800, 1400),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const ProposalListScreen(),
        ),
        GoRoute(
          path: AppRoutes.proposalNew,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('NEW FORM')),
        ),
        GoRoute(
          path: '/proposals/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proposalsApiProvider.overrideWithValue(api),
          currentUserIdProvider.overrideWithValue('u1'),
          debounceTimerFactoryProvider.overrideWithValue(timers.create),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  ProposalListController controllerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ProposalListScreen)))
          .read(proposalListProvider.notifier);

  Finder card(int n) =>
      find.byKey(ValueKey<String>('proposal-card-${proposalId(n)}'));

  Finder inCard(int n, Finder matching) =>
      find.descendant(of: card(n), matching: matching);

  setUp(() {
    api = FakeProposalsApi();
    timers = FakeDebounceTimers();
  });

  group('loading', () {
    testWidgets('shows a spinner, the search field and all chips', (
      tester,
    ) async {
      final List<Gate> gates = <Gate>[];
      api.listHandler = (ListCall call) {
        final Gate gate = Gate();
        gates.add(gate);
        return gate.future;
      };

      await pumpList(tester, settle: false);

      expect(find.byKey(const Key('list-loading')), findsOneWidget);
      expect(find.byKey(const Key('search-field')), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(7));
      expect(find.byKey(const Key('add-proposal')), findsOneWidget);

      gates.single.complete(pageOf(<Proposal>[makeProposal(1)]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-loading')), findsNothing);
      expect(card(1), findsOneWidget);
    });
  });

  group('cards', () {
    testWidgets('show all fields of a proposal', (tester) async {
      api.listHandler = (ListCall call) async => pageOf(<Proposal>[
        makeProposal(
          1,
          title: 'Build a Flutter app',
          company: 'Acme Ltd',
          platform: ProposalPlatform.linkedIn,
          status: ProposalStatus.interview,
          budget: 1234.5,
          followUpDate: CalendarDate(2026, 12, 31),
        ),
      ]);

      await pumpList(tester);

      expect(inCard(1, find.text('Build a Flutter app')), findsOneWidget);
      expect(inCard(1, find.text('Acme Ltd')), findsOneWidget);
      expect(inCard(1, find.text('LinkedIn')), findsOneWidget);
      expect(inCard(1, find.text('Interview')), findsOneWidget);
      expect(inCard(1, find.text(r'$1,234.50')), findsOneWidget);
      expect(inCard(1, find.text('Follow-up 31 Dec 2026')), findsOneWidget);
    });

    testWidgets('hide the fields that are empty', (tester) async {
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);

      await pumpList(tester);

      expect(inCard(1, find.text('Proposal 1')), findsOneWidget);
      expect(inCard(1, find.text('Upwork')), findsOneWidget);
      expect(inCard(1, find.text('Draft')), findsOneWidget);
      expect(inCard(1, find.byIcon(Icons.payments_outlined)), findsNothing);
      expect(inCard(1, find.byIcon(Icons.event)), findsNothing);
    });

    testWidgets('follow-up warning only for Sent or Viewed and a due date', (
      tester,
    ) async {
      final CalendarDate yesterday = CalendarDate(2026, 11, 5);
      final CalendarDate today = CalendarDate(2026, 11, 6);
      final CalendarDate tomorrow = CalendarDate(2026, 11, 7);
      api.listHandler = (ListCall call) async => pageOf(<Proposal>[
        makeProposal(1, status: ProposalStatus.sent, followUpDate: today),
        makeProposal(2, status: ProposalStatus.viewed, followUpDate: yesterday),
        makeProposal(3, status: ProposalStatus.sent, followUpDate: tomorrow),
        makeProposal(4, status: ProposalStatus.draft, followUpDate: yesterday),
        makeProposal(5, status: ProposalStatus.won, followUpDate: yesterday),
        makeProposal(6, status: ProposalStatus.sent),
      ]);

      await pumpList(tester);

      Finder warning(int n) =>
          find.byKey(ValueKey<String>('follow-up-due-${proposalId(n)}'));
      expect(warning(1), findsOneWidget);
      expect(warning(2), findsOneWidget);
      expect(warning(3), findsNothing);
      expect(warning(4), findsNothing);
      expect(warning(5), findsNothing);
      expect(warning(6), findsNothing);
      expect(find.byTooltip('Follow-up is due'), findsNWidgets(2));
    });

    testWidgets('tap opens the detail page', (tester) async {
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);
      await pumpList(tester);

      await tester.tap(card(1));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL ${proposalId(1)}'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('no data at all', (tester) async {
      await pumpList(tester);

      expect(find.byKey(const Key('list-empty')), findsOneWidget);
      expect(find.textContaining('No proposals yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('no result for a filter, and Clear filters', (tester) async {
      api.listHandler = (ListCall call) async => call.status == null
          ? pageOf(<Proposal>[makeProposal(1)])
          : pageOf(<Proposal>[]);
      await pumpList(tester);

      await tester.tap(find.byKey(const Key('filter-sent')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('list-empty-filtered')), findsOneWidget);
      expect(
        find.text('No proposals match your search or filter.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('list-empty')), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(api.listCalls.last.status, isNull);
      expect(card(1), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('filter-all'))).selected,
        isTrue,
      );
    });

    testWidgets('no result for a search, and Clear filters empties the text', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async => call.q == null
          ? pageOf(<Proposal>[makeProposal(1)])
          : pageOf(<Proposal>[]);
      await pumpList(tester);

      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await tester.pump();
      timers.last.fire();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-empty-filtered')), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(api.listCalls.last.q, isNull);
      expect(card(1), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('search-field')))
            .controller!
            .text,
        isEmpty,
      );
    });
  });

  group('filter chips', () {
    testWidgets('All is selected at the start', (tester) async {
      await pumpList(tester);

      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('filter-all'))).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('filter-won'))).selected,
        isFalse,
      );
    });

    testWidgets('a chip sends its status and becomes selected', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const Key('filter-won')));
      await tester.pumpAndSettle();

      expect(api.listCalls.last.status, ProposalStatus.won);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('filter-won'))).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('filter-all'))).selected,
        isFalse,
      );
    });

    testWidgets('All removes the status again', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byKey(const Key('filter-lost')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter-all')));
      await tester.pumpAndSettle();

      expect(api.listCalls.last.status, isNull);
    });

    testWidgets('every status has a chip', (tester) async {
      await pumpList(tester);

      for (final ProposalStatus status in ProposalStatus.values) {
        expect(
          find.byKey(ValueKey<String>('filter-${status.name}')),
          findsOneWidget,
        );
      }
    });
  });

  group('search', () {
    testWidgets('sends the text after the pause, not on every key', (
      tester,
    ) async {
      await pumpList(tester);
      final int before = api.listCalls.length;

      await tester.enterText(find.byKey(const Key('search-field')), 'flu');
      await tester.pump();

      expect(api.listCalls, hasLength(before));
      expect(timers.last.isActive, isTrue);

      timers.last.fire();
      await tester.pumpAndSettle();

      expect(api.listCalls, hasLength(before + 1));
      expect(api.listCalls.last.q, 'flu');
    });

    testWidgets('the clear button empties the text and the search', (
      tester,
    ) async {
      await pumpList(tester);
      expect(find.byKey(const Key('search-clear')), findsNothing);

      await tester.enterText(find.byKey(const Key('search-field')), 'abc');
      await tester.pump();
      timers.last.fire();
      await tester.pumpAndSettle();
      expect(api.listCalls.last.q, 'abc');

      await tester.tap(find.byKey(const Key('search-clear')));
      await tester.pump();
      timers.last.fire();
      await tester.pumpAndSettle();

      expect(api.listCalls.last.q, isNull);
      expect(find.byKey(const Key('search-clear')), findsNothing);
    });
  });

  group('errors', () {
    testWidgets('first load error shows the message and Retry works', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());
      await pumpList(tester);

      expect(find.byKey(const Key('list-error')), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );

      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('list-error')), findsNothing);
      expect(card(1), findsOneWidget);
    });

    testWidgets('rate limit shows the wait time and does not retry', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async => const ApiErr<ProposalPage>(
        ApiError(
          code: ApiErrorCodes.rateLimited,
          message: 'raw',
          retryAfterSeconds: 30,
        ),
      );

      await pumpList(tester);
      await tester.pump(const Duration(seconds: 60));

      expect(
        find.text('Too many requests. Try again in 30 seconds.'),
        findsOneWidget,
      );
      expect(api.listCalls, hasLength(1));
    });

    testWidgets('an error with items on screen shows a banner, items stay', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);
      await pumpList(tester);
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());

      await controllerOf(tester).refresh();
      await tester.pump();

      expect(find.byKey(const Key('list-error-banner')), findsOneWidget);
      expect(find.byKey(const Key('list-error')), findsNothing);
      expect(card(1), findsOneWidget);

      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(2)]);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('list-error-banner')),
          matching: find.text('Retry'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('list-error-banner')), findsNothing);
      expect(card(2), findsOneWidget);
    });
  });

  group('paging and refresh', () {
    testWidgets('loads the next page when the user scrolls near the end', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async => call.cursor == null
          ? pageOf(<Proposal>[
              for (int n = 30; n > 10; n--) makeProposal(n),
            ], next: 'c1')
          : pageOf(<Proposal>[for (int n = 10; n > 5; n--) makeProposal(n)]);
      await pumpList(tester, size: const Size(800, 600));
      expect(api.listCalls, hasLength(1));

      await tester.drag(
        find.byKey(const Key('proposal-list')),
        const Offset(0, -6000),
      );
      await tester.pumpAndSettle();

      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.cursor, 'c1');

      // The new items are below the old end. Scroll down to see them.
      await tester.drag(
        find.byKey(const Key('proposal-list')),
        const Offset(0, -6000),
      );
      await tester.pumpAndSettle();
      expect(card(6), findsOneWidget);
      expect(api.listCalls, hasLength(2));
    });

    testWidgets('a spinner shows while the next page loads', (tester) async {
      final List<Gate> gates = <Gate>[];
      api.listHandler = (ListCall call) {
        if (call.cursor == null) {
          return Future<ApiResult<ProposalPage>>.value(
            pageOf(<Proposal>[
              for (int n = 30; n > 10; n--) makeProposal(n),
            ], next: 'c1'),
          );
        }
        final Gate gate = Gate();
        gates.add(gate);
        return gate.future;
      };
      await pumpList(tester, size: const Size(800, 600));

      await tester.drag(
        find.byKey(const Key('proposal-list')),
        const Offset(0, -6000),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('list-loading-more')), findsOneWidget);

      gates.single.complete(pageOf(<Proposal>[makeProposal(5)]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-loading-more')), findsNothing);
    });

    testWidgets('a short list that does not scroll still loads the next page', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async => call.cursor == null
          ? pageOf(<Proposal>[makeProposal(2)], next: 'c1')
          : pageOf(<Proposal>[makeProposal(1)]);

      await pumpList(tester);

      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.cursor, 'c1');
      expect(card(1), findsOneWidget);
      expect(card(2), findsOneWidget);
    });

    testWidgets('does not ask for a page when there is no next page', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);

      await pumpList(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(api.listCalls, hasLength(1));
    });

    testWidgets('pull to refresh loads page 1 again', (tester) async {
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);
      await pumpList(tester);
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(2)]);

      await tester.fling(
        find.byKey(const Key('proposal-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.cursor, isNull);
      expect(card(2), findsOneWidget);
      expect(card(1), findsNothing);
    });

    testWidgets('pull to refresh also works on the empty screen', (
      tester,
    ) async {
      await pumpList(tester);
      api.listHandler = (ListCall call) async =>
          pageOf(<Proposal>[makeProposal(1)]);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(api.listCalls, hasLength(2));
      expect(card(1), findsOneWidget);
    });
  });

  group('Add proposal', () {
    testWidgets('the button opens the new form', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const Key('add-proposal')));
      await tester.pumpAndSettle();

      expect(find.text('NEW FORM'), findsOneWidget);
    });

    testWidgets('the button is there with data, with an error and when empty', (
      tester,
    ) async {
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());
      await pumpList(tester);

      expect(find.text('Add proposal'), findsOneWidget);
    });
  });
}
