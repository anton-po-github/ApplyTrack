import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/layout/window_size.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/state/stats_provider.dart';
import 'package:apply_track/features/proposals/ui/stats_screen.dart';

import '../../../support/fake_proposals_api.dart';
import '../../../support/fake_stats_api.dart';

void main() {
  const String dash = '\u2014';

  late FakeStatsApi statsApi;
  late FakeProposalsApi proposalsApi;

  const ProposalStats sample = ProposalStats(
    total: 21,
    draft: 1,
    sent: 2,
    viewed: 3,
    interview: 4,
    won: 3,
    lost: 1,
  );

  Future<void> pumpStats(
    WidgetTester tester, {
    double width = 800,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/stats',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                Scaffold(
                  body: Text(
                    'LIST ${ref.watch(proposalListProvider).status?.name ?? 'all'}',
                  ),
                ),
          ),
        ),
        GoRoute(
          path: '/stats',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: StatsScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsApiProvider.overrideWithValue(statsApi),
          proposalsApiProvider.overrideWithValue(proposalsApi),
          currentUserIdProvider.overrideWithValue('u1'),
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

  Finder key(String name) => find.byKey(Key(name));

  String textOf(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(StatsScreen)));

  setUp(() {
    statsApi = FakeStatsApi();
    proposalsApi = FakeProposalsApi();
    statsApi.handler = () async => const ApiOk<ProposalStats>(sample);
  });

  group('columnsFor', () {
    test('1 column on compact, 2 on medium, 3 on expanded', () {
      expect(StatsScreen.columnsFor(WindowSize.compact), 1);
      expect(StatsScreen.columnsFor(WindowSize.medium), 2);
      expect(StatsScreen.columnsFor(WindowSize.expanded), 3);
    });
  });

  group('numbers', () {
    testWidgets('shows total, win rate and the 6 statuses', (tester) async {
      await pumpStats(tester);

      expect(textOf(tester, 'stats-value-total'), '21');
      expect(textOf(tester, 'stats-value-win-rate'), '75%');
      expect(textOf(tester, 'stats-value-draft'), '1');
      expect(textOf(tester, 'stats-value-sent'), '2');
      expect(textOf(tester, 'stats-value-viewed'), '3');
      expect(textOf(tester, 'stats-value-interview'), '4');
      expect(textOf(tester, 'stats-value-won'), '3');
      expect(textOf(tester, 'stats-value-lost'), '1');
      for (final ProposalStatus status in ProposalStatus.values) {
        expect(find.text(status.label), findsOneWidget, reason: status.name);
      }
    });

    testWidgets('win rate is a dash when nothing is decided', (tester) async {
      statsApi.handler = () async =>
          const ApiOk<ProposalStats>(ProposalStats.zero);
      await pumpStats(tester);

      expect(textOf(tester, 'stats-value-win-rate'), dash);
      expect(textOf(tester, 'stats-value-total'), '0');
    });
  });

  group('layout', () {
    Future<int> columnsShown(WidgetTester tester, double width) async {
      await pumpStats(tester, width: width);
      final Set<int> lefts = <int>{
        for (final String name in <String>[
          'total',
          'win-rate',
          ...ProposalStatus.values.map((ProposalStatus s) => s.name),
        ])
          tester.getTopLeft(key('stats-card-$name')).dx.round(),
      };
      return lefts.length;
    }

    testWidgets('400 wide: 1 column', (tester) async {
      expect(await columnsShown(tester, 400), 1);
    });

    testWidgets('700 wide: 2 columns', (tester) async {
      expect(await columnsShown(tester, 700), 2);
    });

    testWidgets('1000 wide: 3 columns', (tester) async {
      expect(await columnsShown(tester, 1000), 3);
    });
  });

  group('tap a status card', () {
    testWidgets('opens the list with that filter', (tester) async {
      await pumpStats(tester);

      await tester.tap(key('stats-card-won'));
      await tester.pumpAndSettle();

      expect(find.text('LIST won'), findsOneWidget);
      expect(proposalsApi.listCalls.last.status, ProposalStatus.won);
    });

    testWidgets('total and win rate are not links', (tester) async {
      await pumpStats(tester);

      await tester.tap(key('stats-card-total'));
      await tester.tap(key('stats-card-win-rate'));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
      expect(proposalsApi.listCalls, isEmpty);
    });
  });

  group('loading and errors', () {
    testWidgets('shows a spinner first', (tester) async {
      final Completer<ApiResult<ProposalStats>> gate =
          Completer<ApiResult<ProposalStats>>();
      statsApi.handler = () => gate.future;
      await pumpStats(tester, settle: false);
      await tester.pump();

      expect(key('stats-loading'), findsOneWidget);
      expect(key('stats-card-total'), findsNothing);

      gate.complete(const ApiOk<ProposalStats>(sample));
      await tester.pumpAndSettle();

      expect(key('stats-loading'), findsNothing);
      expect(textOf(tester, 'stats-value-total'), '21');
    });

    testWidgets('an error without numbers shows Retry, and Retry loads', (
      tester,
    ) async {
      statsApi.handler = () async =>
          const ApiErr<ProposalStats>(ApiError.network());
      await pumpStats(tester);

      expect(key('stats-error'), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );

      statsApi.handler = () async => const ApiOk<ProposalStats>(sample);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(key('stats-error'), findsNothing);
      expect(textOf(tester, 'stats-value-total'), '21');
    });

    testWidgets('an error keeps the old numbers and shows a banner', (
      tester,
    ) async {
      await pumpStats(tester);

      statsApi.handler = () async => const ApiErr<ProposalStats>(
        ApiError(
          code: ApiErrorCodes.rateLimited,
          message: 'Slow down',
          retryAfterSeconds: 7,
        ),
      );
      await containerOf(tester).read(statsProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(textOf(tester, 'stats-value-total'), '21');
      expect(
        find.descendant(
          of: key('stats-error-banner'),
          matching: find.text('Too many requests. Try again in 7 seconds.'),
        ),
        findsOneWidget,
      );

      statsApi.handler = () async => ApiOk<ProposalStats>(statsOf(total: 22));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(key('stats-error-banner'), findsNothing);
      expect(textOf(tester, 'stats-value-total'), '22');
    });

    testWidgets('pull to refresh loads the numbers again', (tester) async {
      await pumpStats(tester);
      expect(statsApi.calls, 1);

      statsApi.handler = () async => ApiOk<ProposalStats>(statsOf(total: 30));
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(statsApi.calls, 2);
      expect(textOf(tester, 'stats-value-total'), '30');
    });
  });
}
