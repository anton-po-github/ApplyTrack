import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposal_list_state.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';

import '../../../support/auth_test_helpers.dart';
import '../../../support/fake_debounce_timers.dart';
import '../../../support/fake_proposals_api.dart';
import '../../../support/proposal_fixtures.dart';

/// A user id that the test can change, like a sign-in or a sign-out.
class TestUserId extends Notifier<String?> {
  TestUserId(this._initial);

  final String? _initial;

  @override
  String? build() => _initial;

  void set(String? value) => state = value;
}

final NotifierProvider<TestUserId, String?> testUserIdProvider =
    NotifierProvider<TestUserId, String?>(() => TestUserId('u1'));

typedef Gate = Completer<ApiResult<ProposalPage>>;

void main() {
  late FakeProposalsApi api;
  late FakeDebounceTimers timers;
  late ProviderContainer container;

  ProposalListState read() => container.read(proposalListProvider);
  ProposalListController controller() =>
      container.read(proposalListProvider.notifier);

  /// Creates the controller and lets the first request finish.
  /// It listens like a widget does. Without a listener Riverpod rebuilds a
  /// provider only when it is read, not when the user changes.
  /// Call it after you set the fake handlers: creating the controller
  /// starts the first request.
  Future<void> start() async {
    container.listen<ProposalListState>(
      proposalListProvider,
      (ProposalListState? previous, ProposalListState next) {},
    );
    await pumpEventQueue();
  }

  /// Every list call waits for the test to complete its gate.
  List<Gate> gateEveryList() {
    final List<Gate> gates = <Gate>[];
    api.listHandler = (ListCall call) {
      final Gate gate = Gate();
      gates.add(gate);
      return gate.future;
    };
    return gates;
  }

  setUp(() {
    api = FakeProposalsApi();
    timers = FakeDebounceTimers();
    container = ProviderContainer(
      overrides: [
        proposalsApiProvider.overrideWithValue(api),
        currentUserIdProvider.overrideWith(
          (Ref ref) => ref.watch(testUserIdProvider),
        ),
        debounceTimerFactoryProvider.overrideWithValue(timers.create),
      ],
    );
    addTearDown(container.dispose);
  });

  group('first load', () {
    test('loads page 1 for a signed-in user', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(2), makeProposal(1)], next: 'c1');

      await start();

      expect(api.listCalls, hasLength(1));
      expect(api.listCalls.single.status, isNull);
      expect(api.listCalls.single.q, isNull);
      expect(api.listCalls.single.cursor, isNull);
      expect(read().phase, ProposalListPhase.loaded);
      expect(read().ids, [proposalId(2), proposalId(1)]);
      expect(read().nextCursor, 'c1');
      expect(read().error, isNull);
    });

    test('shows the loading phase while the request runs', () async {
      final List<Gate> gates = gateEveryList();

      await start();
      expect(read().phase, ProposalListPhase.loading);
      expect(read().isEmpty, isTrue);

      gates.single.complete(pageOf([makeProposal(1)]));
      await pumpEventQueue();
      expect(read().phase, ProposalListPhase.loaded);
    });

    test('does nothing when nobody is signed in', () async {
      container.read(testUserIdProvider.notifier).set(null);

      await start();
      await controller().refresh();
      await controller().loadMore();
      await controller().setStatus(ProposalStatus.won);

      expect(api.listCalls, isEmpty);
    });

    test('starts when the user signs in later', () async {
      container.read(testUserIdProvider.notifier).set(null);
      await start();
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);

      container.read(testUserIdProvider.notifier).set('u2');
      await pumpEventQueue();

      expect(api.listCalls, hasLength(1));
      expect(read().ids, [proposalId(1)]);
    });

    test('a failed first load gives the error phase and no items', () async {
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());

      await start();

      expect(read().phase, ProposalListPhase.error);
      expect(read().error?.code, ApiErrorCodes.network);
      expect(read().isEmpty, isTrue);
    });

    test('retry after a failed first load loads page 1 again', () async {
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());
      await start();

      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await controller().retry();

      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.cursor, isNull);
      expect(read().phase, ProposalListPhase.loaded);
      expect(read().error, isNull);
      expect(read().length, 1);
    });

    test('retry does nothing when there is no error', () async {
      await start();

      await controller().retry();

      expect(api.listCalls, hasLength(1));
    });

    test(
      'rate limit: keeps the seconds and does not retry by itself',
      () async {
        api.listHandler = (ListCall call) async => const ApiErr<ProposalPage>(
          ApiError(
            code: ApiErrorCodes.rateLimited,
            message: 'Too many requests.',
            retryAfterSeconds: 30,
          ),
        );

        await start();
        await pumpEventQueue();

        expect(api.listCalls, hasLength(1));
        expect(read().phase, ProposalListPhase.error);
        expect(read().error?.code, ApiErrorCodes.rateLimited);
        expect(read().error?.retryAfterSeconds, 30);
      },
    );
  });

  group('refresh', () {
    test('keeps the items on screen while it runs', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      final List<Gate> gates = gateEveryList();

      final Future<void> running = controller().refresh();

      expect(read().phase, ProposalListPhase.loading);
      expect(read().ids, [proposalId(1)]);

      gates.single.complete(pageOf([makeProposal(2)]));
      await running;
      expect(read().ids, [proposalId(2)]);
    });

    test('a failed refresh keeps the old items', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());

      await controller().refresh();

      expect(read().phase, ProposalListPhase.error);
      expect(read().ids, [proposalId(1)]);
    });
  });

  group('loadMore', () {
    setUp(() {
      api.listHandler = (ListCall call) async => call.cursor == null
          ? pageOf([makeProposal(3), makeProposal(2)], next: 'c1')
          : pageOf([makeProposal(1)]);
    });

    test('appends the next page with the cursor', () async {
      await start();

      await controller().loadMore();

      expect(api.listCalls.last.cursor, 'c1');
      expect(read().ids, [proposalId(3), proposalId(2), proposalId(1)]);
      expect(read().nextCursor, isNull);
      expect(read().phase, ProposalListPhase.loaded);
    });

    test('sends the same filter and search with the cursor', () async {
      await start();
      await controller().setStatus(ProposalStatus.sent);
      controller().setQuery('  flutter ');
      timers.last.fire();
      await pumpEventQueue();

      await controller().loadMore();

      expect(api.listCalls.last.status, ProposalStatus.sent);
      expect(api.listCalls.last.q, 'flutter');
      expect(api.listCalls.last.cursor, 'c1');
    });

    test('shows loadingMore while it runs', () async {
      await start();
      final List<Gate> gates = gateEveryList();

      final Future<void> running = controller().loadMore();
      expect(read().phase, ProposalListPhase.loadingMore);
      expect(read().length, 2);

      gates.single.complete(pageOf([makeProposal(1)]));
      await running;
      expect(read().phase, ProposalListPhase.loaded);
    });

    test('does nothing on the last page', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();

      await controller().loadMore();

      expect(api.listCalls, hasLength(1));
    });

    test(
      'a second call while one runs does not send a second request',
      () async {
        await start();
        final List<Gate> gates = gateEveryList();

        final Future<void> first = controller().loadMore();
        await controller().loadMore();

        expect(gates, hasLength(1));
        gates.single.complete(pageOf([makeProposal(1)]));
        await first;
      },
    );

    test('does not add an item twice', () async {
      api.listHandler = (ListCall call) async => call.cursor == null
          ? pageOf([makeProposal(2), makeProposal(1)], next: 'c1')
          : pageOf([makeProposal(1)]);
      await start();

      await controller().loadMore();

      expect(read().ids, [proposalId(2), proposalId(1)]);
    });

    test('a cursor that does not move ends the list', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(call.cursor == null ? 1 : 2)], next: 'c1');
      await start();

      await controller().loadMore();

      expect(read().nextCursor, isNull);
      await controller().loadMore();
      expect(api.listCalls, hasLength(2));
    });

    test('an error keeps the items. Scrolling does not repeat it', () async {
      await start();
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());

      await controller().loadMore();
      await controller().loadMore();

      expect(api.listCalls, hasLength(2));
      expect(read().phase, ProposalListPhase.error);
      expect(read().length, 2);
      expect(read().nextCursor, 'c1');
    });

    test('retry after a loadMore error asks for the same cursor', () async {
      await start();
      api.listHandler = (ListCall call) async =>
          const ApiErr<ProposalPage>(ApiError.network());
      await controller().loadMore();

      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await controller().retry();

      expect(api.listCalls.last.cursor, 'c1');
      expect(read().ids, [proposalId(3), proposalId(2), proposalId(1)]);
      expect(read().phase, ProposalListPhase.loaded);
    });
  });

  group('status filter', () {
    test('resets items and cursor and sends the status', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(1)], next: 'c1');
      await start();

      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(2, status: ProposalStatus.won)]);
      await controller().setStatus(ProposalStatus.won);

      expect(api.listCalls.last.status, ProposalStatus.won);
      expect(api.listCalls.last.cursor, isNull);
      expect(read().status, ProposalStatus.won);
      expect(read().ids, [proposalId(2)]);
      expect(read().nextCursor, isNull);
    });

    test('the old items are gone while the new filter loads', () async {
      await start();
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await controller().refresh();
      final List<Gate> gates = gateEveryList();

      final Future<void> running = controller().setStatus(ProposalStatus.lost);

      expect(read().isEmpty, isTrue);
      expect(read().phase, ProposalListPhase.loading);
      gates.single.complete(pageOf(<Proposal>[]));
      await running;
    });

    test('the same status does nothing. Null means All', () async {
      await start();

      await controller().setStatus(null);
      expect(api.listCalls, hasLength(1));

      await controller().setStatus(ProposalStatus.sent);
      await controller().setStatus(ProposalStatus.sent);
      expect(api.listCalls, hasLength(2));

      await controller().setStatus(null);
      expect(api.listCalls, hasLength(3));
      expect(api.listCalls.last.status, isNull);
    });

    test('keeps the search text when the status changes', () async {
      await start();
      controller().setQuery('flutter');
      timers.last.fire();
      await pumpEventQueue();

      await controller().setStatus(ProposalStatus.sent);

      expect(api.listCalls.last.q, 'flutter');
      expect(api.listCalls.last.status, ProposalStatus.sent);
    });
  });

  group('search', () {
    test('waits for the pause. Only the last text is sent', () async {
      await start();

      controller().setQuery('f');
      controller().setQuery('fl');
      controller().setQuery('flu');

      expect(timers.created, hasLength(3));
      expect(timers.created[0].cancelled, isTrue);
      expect(timers.created[1].cancelled, isTrue);
      expect(timers.last.isActive, isTrue);
      expect(timers.last.delay, const Duration(milliseconds: 400));
      expect(api.listCalls, hasLength(1));

      timers.last.fire();
      await pumpEventQueue();

      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.q, 'flu');
      expect(read().query, 'flu');
    });

    test('trims the text. Blank text clears the search', () async {
      await start();
      controller().setQuery('  flutter  ');
      timers.last.fire();
      await pumpEventQueue();
      expect(api.listCalls.last.q, 'flutter');

      controller().setQuery('   ');
      timers.last.fire();
      await pumpEventQueue();

      expect(api.listCalls.last.q, isNull);
      expect(read().query, isNull);
    });

    test('a new search resets the cursor and the items', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(1)], next: 'c1');
      await start();

      api.listHandler = (ListCall call) async => pageOf([makeProposal(5)]);
      controller().setQuery('x');
      timers.last.fire();
      await pumpEventQueue();

      expect(api.listCalls.last.cursor, isNull);
      expect(read().ids, [proposalId(5)]);
      expect(read().nextCursor, isNull);
    });

    test('typing the applied text again starts no timer', () async {
      await start();

      controller().setQuery(null);
      controller().setQuery('  ');

      expect(timers.created, isEmpty);
    });

    test('typing back to the applied text cancels the waiting timer', () async {
      await start();
      controller().setQuery('abc');
      timers.last.fire();
      await pumpEventQueue();
      final int calls = api.listCalls.length;

      controller().setQuery('abcd');
      final FakeTimer waiting = timers.last;
      controller().setQuery('abc');

      expect(waiting.cancelled, isTrue);
      waiting.fire();
      await pumpEventQueue();
      expect(api.listCalls, hasLength(calls));
    });

    test('text the server would refuse is never sent', () async {
      await start();

      controller().setQuery('a' * 101);
      controller().setQuery('a\nb');

      expect(timers.created, isEmpty);
      expect(api.listCalls, hasLength(1));
    });

    test('a timer that fires after sign-out sends nothing', () async {
      await start();
      controller().setQuery('abc');
      final FakeTimer waiting = timers.last;

      container.read(testUserIdProvider.notifier).set(null);
      await pumpEventQueue();
      waiting.fire();
      await pumpEventQueue();

      expect(api.listCalls, hasLength(1));
    });
  });

  group('old answers', () {
    test('a slow answer never replaces a newer one', () async {
      final List<Gate> gates = gateEveryList();
      await start(); // gates[0] is the first request.

      final Future<void> filtering = controller().setStatus(ProposalStatus.won);
      await pumpEventQueue(); // gates[1] is the filtered request.

      gates[1].complete(pageOf([makeProposal(2, status: ProposalStatus.won)]));
      await filtering;
      gates[0].complete(pageOf([makeProposal(1)]));
      await pumpEventQueue();

      expect(read().status, ProposalStatus.won);
      expect(read().ids, [proposalId(2)]);
    });

    test('a loadMore answer after a filter change is dropped', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(1)], next: 'c1');
      await start();
      final List<Gate> gates = gateEveryList();

      final Future<void> more = controller().loadMore(); // gates[0]
      final Future<void> filtering = controller().setStatus(
        ProposalStatus.lost,
      ); // gates[1]
      await pumpEventQueue();

      gates[1].complete(pageOf([makeProposal(9, status: ProposalStatus.lost)]));
      await filtering;
      gates[0].complete(pageOf([makeProposal(0)]));
      await more;

      expect(read().ids, [proposalId(9)]);
    });

    test('an old error does not replace newer data', () async {
      final List<Gate> gates = gateEveryList();
      await start();

      final Future<void> second = controller().refresh();
      await pumpEventQueue();

      gates[1].complete(pageOf([makeProposal(2)]));
      await second;
      gates[0].complete(const ApiErr<ProposalPage>(ApiError.network()));
      await pumpEventQueue();

      expect(read().phase, ProposalListPhase.loaded);
      expect(read().ids, [proposalId(2)]);
    });
  });

  group('user change', () {
    test('sign-out drops the list at once', () async {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(1)], next: 'c1');
      await start();
      expect(read().length, 1);

      container.read(testUserIdProvider.notifier).set(null);

      expect(read().isEmpty, isTrue);
      expect(read().nextCursor, isNull);
      expect(read().hasFilter, isFalse);
    });

    test('an answer that arrives after sign-out is ignored', () async {
      final List<Gate> gates = gateEveryList();
      await start();

      container.read(testUserIdProvider.notifier).set(null);
      gates.single.complete(pageOf([makeProposal(1)]));
      await pumpEventQueue();

      expect(read().isEmpty, isTrue);
    });

    test('another user starts with a clean list and no old filter', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      await controller().setStatus(ProposalStatus.won);

      api.listHandler = (ListCall call) async => pageOf([makeProposal(7)]);
      container.read(testUserIdProvider.notifier).set('u2');
      await pumpEventQueue();

      expect(api.listCalls.last.status, isNull);
      expect(api.listCalls.last.q, isNull);
      expect(read().ids, [proposalId(7)]);
      expect(read().status, isNull);
    });

    test('the real sign-out of the auth controller drops the list', () async {
      final FakeAuthRepository repo = FakeAuthRepository(
        session: validSession(),
      );
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      final ProviderContainer real = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          googleSignInProvider.overrideWithValue(FakeGoogleIdTokenProvider()),
          proposalsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(real.dispose);
      real.read(authControllerProvider);
      await pumpEventQueue();
      expect(real.read(authControllerProvider), isA<AuthSignedIn>());

      real.read(proposalListProvider);
      await pumpEventQueue();
      expect(real.read(proposalListProvider).length, 1);

      await real.read(authControllerProvider.notifier).signOut();
      await pumpEventQueue();

      expect(real.read(authControllerProvider), isA<AuthSignedOut>());
      expect(real.read(proposalListProvider).isEmpty, isTrue);
      expect(api.listCalls, hasLength(1));
    });
  });

  group('create', () {
    test('sends the draft and loads page 1 again', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      api.createHandler = (draft) async => ApiOk<Proposal>(makeProposal(2));
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(2), makeProposal(1)]);

      final ApiResult<Proposal> result = await controller().create(
        validDraft(),
      );
      await pumpEventQueue();

      expect(result, isA<ApiOk<Proposal>>());
      expect(api.createCalls, hasLength(1));
      expect(api.listCalls, hasLength(2));
      expect(api.listCalls.last.cursor, isNull);
      expect(read().ids, [proposalId(2), proposalId(1)]);
    });

    test('a bad draft never reaches the server', () async {
      await start();

      final ApiResult<Proposal> result = await controller().create(
        validDraft(title: 'ab'),
      );

      final ApiError error = (result as ApiErr<Proposal>).error;
      expect(error.code, ApiErrorCodes.validation);
      expect(error.fields, contains('title'));
      expect(api.createCalls, isEmpty);
      expect(read().isWriting, isFalse);
    });

    test('a server error passes through and the list stays as it is', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      api.createHandler = (draft) async => const ApiErr<Proposal>(
        ApiError(code: ApiErrorCodes.proposalLimit, message: 'Limit reached.'),
      );

      final ApiResult<Proposal> result = await controller().create(
        validDraft(),
      );
      await pumpEventQueue();

      expect((result as ApiErr<Proposal>).error.code, 'proposal_limit');
      expect(api.listCalls, hasLength(1));
      expect(read().ids, [proposalId(1)]);
      expect(read().phase, ProposalListPhase.loaded);
      expect(read().isWriting, isFalse);
    });

    test('a second tap while the first runs is refused', () async {
      await start();
      final Completer<ApiResult<Proposal>> gate =
          Completer<ApiResult<Proposal>>();
      api.createHandler = (draft) => gate.future;

      final Future<ApiResult<Proposal>> first = controller().create(
        validDraft(),
      );
      expect(read().isWriting, isTrue);
      final ApiResult<Proposal> second = await controller().create(
        validDraft(),
      );

      expect(second, isA<ApiErr<Proposal>>());
      expect(api.createCalls, hasLength(1));

      gate.complete(ApiOk<Proposal>(makeProposal(2)));
      await first;
      expect(read().isWriting, isFalse);
    });

    test('a signed-out user gets unauthorized and no request', () async {
      container.read(testUserIdProvider.notifier).set(null);
      await start();

      final ApiResult<Proposal> result = await controller().create(
        validDraft(),
      );

      expect(
        (result as ApiErr<Proposal>).error.code,
        ApiErrorCodes.unauthorized,
      );
      expect(api.createCalls, isEmpty);
    });
  });

  group('update', () {
    setUp(() {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(3), makeProposal(2), makeProposal(1)]);
    });

    test('puts the server answer in the same place', () async {
      await start();
      api.updateHandler = (id, draft) async => ApiOk<Proposal>(
        makeProposal(2, title: 'Server title', status: ProposalStatus.sent),
      );

      final ApiResult<Proposal> result = await controller().update(
        proposalId(2),
        validDraft(title: 'My title', status: ProposalStatus.sent),
      );

      expect(result, isA<ApiOk<Proposal>>());
      expect(api.updateIds, [proposalId(2)]);
      expect(read().ids, [proposalId(3), proposalId(2), proposalId(1)]);
      expect(read().proposalById(proposalId(2))?.title, 'Server title');
      expect(api.listCalls, hasLength(1));
    });

    test('removes the item when it leaves the status filter', () async {
      await start();
      await controller().setStatus(ProposalStatus.draft);
      api.updateHandler = (id, draft) async =>
          ApiOk<Proposal>(makeProposal(2, status: ProposalStatus.sent));

      await controller().update(
        proposalId(2),
        validDraft(status: ProposalStatus.sent),
      );

      expect(read().ids, [proposalId(3), proposalId(1)]);
      expect(read().proposalById(proposalId(2)), isNull);
    });

    test('keeps the item when it still matches the status filter', () async {
      await start();
      await controller().setStatus(ProposalStatus.draft);
      api.updateHandler = (id, draft) async =>
          ApiOk<Proposal>(makeProposal(2, title: 'New'));

      await controller().update(proposalId(2), validDraft(title: 'New'));

      expect(read().ids, hasLength(3));
      expect(read().proposalById(proposalId(2))?.title, 'New');
    });

    test('an error leaves the list unchanged', () async {
      await start();
      api.updateHandler = (id, draft) async =>
          const ApiErr<Proposal>(ApiError.network());

      final ApiResult<Proposal> result = await controller().update(
        proposalId(2),
        validDraft(),
      );

      expect((result as ApiErr<Proposal>).error.code, ApiErrorCodes.network);
      expect(read().proposalById(proposalId(2))?.title, 'Proposal 2');
      expect(read().isWriting, isFalse);
    });

    test('not_found removes the item and returns the error', () async {
      await start();
      api.updateHandler = (id, draft) async => const ApiErr<Proposal>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
      );

      final ApiResult<Proposal> result = await controller().update(
        proposalId(2),
        validDraft(),
      );

      expect((result as ApiErr<Proposal>).error.code, ApiErrorCodes.notFound);
      expect(read().ids, [proposalId(3), proposalId(1)]);
    });

    test('a bad draft never reaches the server', () async {
      await start();

      final ApiResult<Proposal> result = await controller().update(
        proposalId(2),
        validDraft(title: ''),
      );

      expect((result as ApiErr<Proposal>).error.fields, contains('title'));
      expect(api.updateIds, isEmpty);
    });

    test('an item that is not loaded does not break anything', () async {
      await start();
      api.updateHandler = (id, draft) async =>
          ApiOk<Proposal>(makeProposal(99));

      await controller().update(proposalId(99), validDraft());

      expect(read().ids, hasLength(3));
      expect(read().proposalById(proposalId(99)), isNull);
    });
  });

  group('delete', () {
    setUp(() {
      api.listHandler = (ListCall call) async =>
          pageOf([makeProposal(2), makeProposal(1)]);
    });

    test('removes the item from the list', () async {
      await start();

      final ApiResult<void> result = await controller().delete(proposalId(2));

      expect(result, isA<ApiOk<void>>());
      expect(api.deleteIds, [proposalId(2)]);
      expect(read().ids, [proposalId(1)]);
      expect(read().proposalById(proposalId(2)), isNull);
    });

    test('not_found counts as gone: removed, error returned', () async {
      await start();
      api.deleteHandler = (id) async => const ApiErr<void>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
      );

      final ApiResult<void> result = await controller().delete(proposalId(2));

      expect((result as ApiErr<void>).error.code, ApiErrorCodes.notFound);
      expect(read().ids, [proposalId(1)]);
    });

    test('another error keeps the item', () async {
      await start();
      api.deleteHandler = (id) async => const ApiErr<void>(ApiError.network());

      await controller().delete(proposalId(2));

      expect(read().ids, [proposalId(2), proposalId(1)]);
      expect(read().isWriting, isFalse);
    });

    test('a second tap while the first runs is refused', () async {
      await start();
      final Completer<ApiResult<void>> gate = Completer<ApiResult<void>>();
      api.deleteHandler = (id) => gate.future;

      final Future<ApiResult<void>> first = controller().delete(proposalId(2));
      final ApiResult<void> second = await controller().delete(proposalId(1));

      expect(second, isA<ApiErr<void>>());
      expect(api.deleteIds, [proposalId(2)]);

      gate.complete(const ApiOk<void>(null));
      await first;
      expect(read().ids, [proposalId(1)]);
    });

    test('a write answer after sign-out changes nothing', () async {
      await start();
      final Completer<ApiResult<void>> gate = Completer<ApiResult<void>>();
      api.deleteHandler = (id) => gate.future;

      final Future<ApiResult<void>> running = controller().delete(
        proposalId(2),
      );
      container.read(testUserIdProvider.notifier).set(null);
      gate.complete(const ApiOk<void>(null));
      await running;

      expect(read().isEmpty, isTrue);
      expect(container.read(proposalsChangedProvider), 0);
    });
  });

  group('stats signal', () {
    test('goes up after every successful write', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      api.createHandler = (draft) async => ApiOk<Proposal>(makeProposal(2));
      api.updateHandler = (id, draft) async =>
          ApiOk<Proposal>(makeProposal(1, title: 'x'));
      expect(container.read(proposalsChangedProvider), 0);

      await controller().create(validDraft());
      expect(container.read(proposalsChangedProvider), 1);
      await controller().update(proposalId(1), validDraft());
      expect(container.read(proposalsChangedProvider), 2);
      await controller().delete(proposalId(1));
      expect(container.read(proposalsChangedProvider), 3);
    });

    test('stays the same after a failed write or a bad draft', () async {
      await start();
      api.createHandler = (draft) async =>
          const ApiErr<Proposal>(ApiError.network());

      await controller().create(validDraft());
      await controller().create(validDraft(title: 'a'));

      expect(container.read(proposalsChangedProvider), 0);
    });

    test('goes up when a delete finds the item already gone', () async {
      api.listHandler = (ListCall call) async => pageOf([makeProposal(1)]);
      await start();
      api.deleteHandler = (id) async => const ApiErr<void>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
      );

      await controller().delete(proposalId(1));

      expect(container.read(proposalsChangedProvider), 1);
    });
  });

  group('clearFilters', () {
    test('removes status and search and loads page 1 at once', () async {
      await start();
      await controller().setStatus(ProposalStatus.won);
      controller().setQuery('flutter');
      timers.last.fire();
      await pumpEventQueue();
      expect(read().hasFilter, isTrue);
      final int calls = api.listCalls.length;

      await controller().clearFilters();

      expect(api.listCalls, hasLength(calls + 1));
      expect(api.listCalls.last.status, isNull);
      expect(api.listCalls.last.q, isNull);
      expect(api.listCalls.last.cursor, isNull);
      expect(read().hasFilter, isFalse);
    });

    test('cancels a search that is still waiting', () async {
      await start();
      await controller().setStatus(ProposalStatus.won);
      controller().setQuery('abc');
      final FakeTimer waiting = timers.last;

      await controller().clearFilters();
      final int calls = api.listCalls.length;
      waiting.fire();
      await pumpEventQueue();

      expect(waiting.cancelled, isTrue);
      expect(api.listCalls, hasLength(calls));
      expect(read().query, isNull);
    });

    test('does nothing when there is no filter', () async {
      await start();

      await controller().clearFilters();

      expect(api.listCalls, hasLength(1));
    });

    test('does nothing when nobody is signed in', () async {
      await start();
      container.read(testUserIdProvider.notifier).set(null);

      await controller().clearFilters();

      expect(api.listCalls, hasLength(1));
    });
  });
}
