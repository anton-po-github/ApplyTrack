import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposal_list_state.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/state/stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_proposals_api.dart';
import '../../../support/fake_stats_api.dart';
import '../../../support/proposal_fixtures.dart';

/// A user id that the test can change, like a sign-in or a sign-out.
class TestUserId extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? value) => state = value;
}

final NotifierProvider<TestUserId, String?> testUserIdProvider =
    NotifierProvider<TestUserId, String?>(TestUserId.new);

typedef Gate = Completer<ApiResult<ProposalStats>>;

void main() {
  late FakeStatsApi api;
  late FakeProposalsApi proposalsApi;
  late ProviderContainer container;

  StatsState read() => container.read(statsProvider);
  StatsController controller() => container.read(statsProvider.notifier);

  /// Creates the state and lets the first request finish. It listens like a
  /// widget does. Call it after you set the fake handlers: creating the
  /// provider starts the first request.
  Future<void> start() async {
    container.listen<StatsState>(statsProvider, (previous, next) {});
    await pumpEventQueue();
  }

  List<Gate> gateEveryCall() {
    final gates = <Gate>[];
    api.handler = () {
      final gate = Gate();
      gates.add(gate);
      return gate.future;
    };
    return gates;
  }

  ApiResult<ProposalStats> ok(ProposalStats stats) =>
      ApiOk<ProposalStats>(stats);

  setUp(() {
    api = FakeStatsApi();
    proposalsApi = FakeProposalsApi();
    container = ProviderContainer(
      overrides: [
        statsApiProvider.overrideWithValue(api),
        proposalsApiProvider.overrideWithValue(proposalsApi),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(testUserIdProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  group('StatsState', () {
    test('copyWith keeps, changes and clears values', () {
      const failure = ApiError.network();
      final full = StatsState(
        stats: statsOf(total: 3),
        isLoading: true,
        error: failure,
      );

      expect(full.copyWith().stats, statsOf(total: 3));
      expect(full.copyWith().error, same(failure));
      expect(full.copyWith(isLoading: false).isLoading, isFalse);
      expect(full.copyWith(stats: null).hasData, isFalse);
      expect(full.copyWith(error: null).error, isNull);
      expect(full.hasData, isTrue);
    });
  });

  group('load', () {
    test('loads the numbers for a signed-in user', () async {
      api.handler = () async => ok(statsOf(total: 5, won: 2, lost: 1));

      await start();

      expect(api.calls, 1);
      expect(read().stats, statsOf(total: 5, won: 2, lost: 1));
      expect(read().isLoading, isFalse);
      expect(read().error, isNull);
    });

    test('is loading and has no numbers before the first answer', () async {
      final gates = gateEveryCall();

      await start();
      expect(read().isLoading, isTrue);
      expect(read().hasData, isFalse);

      gates.single.complete(ok(statsOf(total: 1)));
      await pumpEventQueue();
      expect(read().isLoading, isFalse);
      expect(read().stats?.total, 1);
    });

    test('does nothing when nobody is signed in', () async {
      container.read(testUserIdProvider.notifier).set(null);

      await start();
      await controller().refresh();

      expect(api.calls, 0);
      expect(read().isLoading, isFalse);
      expect(read().hasData, isFalse);
    });

    test('starts when the user signs in later', () async {
      container.read(testUserIdProvider.notifier).set(null);
      await start();
      api.handler = () async => ok(statsOf(total: 4));

      container.read(testUserIdProvider.notifier).set('u2');
      await pumpEventQueue();

      expect(api.calls, 1);
      expect(read().stats?.total, 4);
    });
  });

  group('error', () {
    test('a failed first load gives the error and no numbers', () async {
      api.handler = () async => const ApiErr<ProposalStats>(ApiError.network());

      await start();

      expect(read().error?.code, ApiErrorCodes.network);
      expect(read().hasData, isFalse);
      expect(read().isLoading, isFalse);
      expect(api.calls, 1); // No auto-retry.
    });

    test('a failed refresh keeps the last good numbers', () async {
      api.handler = () async => ok(statsOf(total: 5));
      await start();
      api.handler = () async => const ApiErr<ProposalStats>(ApiError.network());

      await controller().refresh();

      expect(read().stats?.total, 5);
      expect(read().error?.code, ApiErrorCodes.network);
      expect(read().isLoading, isFalse);
    });

    test('a good refresh after an error clears the error', () async {
      api.handler = () async => const ApiErr<ProposalStats>(ApiError.network());
      await start();
      api.handler = () async => ok(statsOf(total: 2));

      await controller().refresh();

      expect(read().error, isNull);
      expect(read().stats?.total, 2);
    });

    test('keeps the rate limit seconds', () async {
      api.handler = () async => const ApiErr<ProposalStats>(
        ApiError(
          code: ApiErrorCodes.rateLimited,
          message: 'Too many requests.',
          retryAfterSeconds: 20,
        ),
      );

      await start();

      expect(read().error?.retryAfterSeconds, 20);
    });
  });

  group('refresh', () {
    test('keeps the old numbers while it runs', () async {
      api.handler = () async => ok(statsOf(total: 5));
      await start();
      final gates = gateEveryCall();

      final running = controller().refresh();

      expect(read().isLoading, isTrue);
      expect(read().stats?.total, 5);

      gates.single.complete(ok(statsOf(total: 6)));
      await running;
      expect(read().isLoading, isFalse);
      expect(read().stats?.total, 6);
    });

    test('a slow old answer never replaces a newer one', () async {
      final gates = gateEveryCall();
      await start(); // gates[0]

      final second = controller().refresh(); // gates[1]
      await pumpEventQueue();
      gates[1].complete(ok(statsOf(total: 2)));
      await second;
      gates[0].complete(ok(statsOf(total: 1)));
      await pumpEventQueue();

      expect(read().stats?.total, 2);
    });

    test('an old error does not replace newer numbers', () async {
      final gates = gateEveryCall();
      await start();

      final second = controller().refresh();
      await pumpEventQueue();
      gates[1].complete(ok(statsOf(total: 2)));
      await second;
      gates[0].complete(const ApiErr<ProposalStats>(ApiError.network()));
      await pumpEventQueue();

      expect(read().error, isNull);
      expect(read().stats?.total, 2);
    });
  });

  group('after a write', () {
    test('loads again when the write signal goes up', () async {
      api.handler = () async => ok(statsOf(total: 1));
      await start();
      api.handler = () async => ok(statsOf(total: 2));

      container.read(proposalsChangedProvider.notifier).notify();
      await pumpEventQueue();

      expect(api.calls, 2);
      expect(read().stats?.total, 2);
    });

    test('keeps the old numbers while the new ones load', () async {
      api.handler = () async => ok(statsOf(total: 1));
      await start();
      final gates = gateEveryCall();

      container.read(proposalsChangedProvider.notifier).notify();
      await pumpEventQueue();

      expect(read().isLoading, isTrue);
      expect(read().stats?.total, 1);
      gates.single.complete(ok(statsOf(total: 2)));
      await pumpEventQueue();
      expect(read().stats?.total, 2);
    });

    test('a real delete in the list refreshes the stats', () async {
      proposalsApi.listHandler = (call) async => pageOf([makeProposal(1)]);
      api.handler = () async => ok(statsOf(total: 1));
      container.listen<ProposalListState>(
        proposalListProvider,
        (previous, next) {},
      );
      await start();
      expect(api.calls, 1);

      api.handler = () async => ok(statsOf());
      await container.read(proposalListProvider.notifier).delete(proposalId(1));
      await pumpEventQueue();

      expect(api.calls, 2);
      expect(read().stats?.total, 0);
    });

    test('a failed write does not refresh the stats', () async {
      api.handler = () async => ok(statsOf(total: 1));
      container.listen<ProposalListState>(
        proposalListProvider,
        (previous, next) {},
      );
      await start();
      proposalsApi.deleteHandler = (id) async =>
          const ApiErr<void>(ApiError.network());

      await container.read(proposalListProvider.notifier).delete(proposalId(1));
      await pumpEventQueue();

      expect(api.calls, 1);
    });
  });

  group('user change', () {
    test('sign-out drops the numbers at once', () async {
      api.handler = () async => ok(statsOf(total: 5));
      await start();
      expect(read().hasData, isTrue);

      container.read(testUserIdProvider.notifier).set(null);

      expect(read().hasData, isFalse);
      expect(read().isLoading, isFalse);
      expect(read().error, isNull);
    });

    test('an answer that arrives after sign-out is ignored', () async {
      final gates = gateEveryCall();
      await start();

      container.read(testUserIdProvider.notifier).set(null);
      gates.single.complete(ok(statsOf(total: 9)));
      await pumpEventQueue();

      expect(read().hasData, isFalse);
    });

    test('a write signal after sign-out sends no request', () async {
      await start();
      container.read(testUserIdProvider.notifier).set(null);
      await pumpEventQueue();

      container.read(proposalsChangedProvider.notifier).notify();
      await pumpEventQueue();

      expect(api.calls, 1);
    });

    test('another user starts clean and never sees old numbers', () async {
      api.handler = () async => ok(statsOf(total: 5));
      await start();
      final gates = gateEveryCall();

      container.read(testUserIdProvider.notifier).set('u2');
      await pumpEventQueue();

      expect(read().hasData, isFalse);
      expect(read().isLoading, isTrue);
      gates.single.complete(ok(statsOf(total: 7)));
      await pumpEventQueue();
      expect(read().stats?.total, 7);
    });
  });
}
