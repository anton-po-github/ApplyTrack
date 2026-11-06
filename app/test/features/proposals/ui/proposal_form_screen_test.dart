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
import 'package:apply_track/features/proposals/ui/proposal_form_screen.dart';
import 'package:apply_track/router/app_router.dart';

import '../../../support/app_test_helpers.dart';
import '../../../support/fake_proposals_api.dart';
import '../../../support/proposal_fixtures.dart';

void main() {
  late FakeProposalsApi api;

  // A proposal with every field filled. Its id is [routeTestId].
  final Proposal fullProposal = Proposal(
    id: routeTestId,
    title: 'Server title',
    company: 'Acme',
    platform: ProposalPlatform.email,
    status: ProposalStatus.viewed,
    budget: 99.5,
    followUpDate: CalendarDate(2026, 12, 1),
    link: 'https://acme.io/job',
    notes: 'Line one\nLine two',
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
                  key: const Key('open-new'),
                  onPressed: () => context.push(AppRoutes.proposalNew),
                  child: const Text('open new'),
                ),
                TextButton(
                  key: const Key('open-edit'),
                  onPressed: () =>
                      context.push(AppRoutes.proposalEdit(routeTestId)),
                  child: const Text('open edit'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.proposalNew,
          builder: (BuildContext context, GoRouterState state) =>
              const ProposalFormScreen(),
        ),
        GoRoute(
          path: '/proposals/:id/edit',
          builder: (BuildContext context, GoRouterState state) =>
              ProposalFormScreen(proposalId: state.pathParameters['id']),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proposalsApiProvider.overrideWithValue(api),
          currentUserIdProvider.overrideWithValue('u1'),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 6, 10)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNew(WidgetTester tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('open-new')));
    await tester.pumpAndSettle();
  }

  Future<void> openEdit(WidgetTester tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('open-edit')));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const Key('save-button')))
          .onPressed !=
      null;

  setUp(() {
    api = FakeProposalsApi();
    api.createHandler = (ProposalDraft draft) async =>
        ApiOk<Proposal>(makeProposal(1));
    api.updateHandler = (String id, ProposalDraft draft) async =>
        ApiOk<Proposal>(fullProposal);
  });

  group('new proposal', () {
    testWidgets('shows all inputs, empty, with the notes counter', (
      tester,
    ) async {
      await openNew(tester);

      expect(find.text('New proposal'), findsOneWidget);
      for (final String key in <String>[
        'field-title',
        'field-company',
        'field-platform',
        'field-status',
        'field-budget',
        'field-follow-up',
        'field-link',
        'field-notes',
        'save-button',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(textOf(tester, 'field-title'), isEmpty);
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byKey(const Key('follow-up-clear')), findsNothing);
      expect(find.byKey(const Key('form-error-banner')), findsNothing);
    });

    testWidgets('the notes counter follows the text', (tester) async {
      await openNew(tester);

      await type(tester, 'field-notes', 'abc');

      expect(find.text('3/2000'), findsOneWidget);
    });

    testWidgets('an empty title is refused and nothing is sent', (
      tester,
    ) async {
      await openNew(tester);

      await save(tester);

      expect(find.text('Title is required'), findsOneWidget);
      expect(api.createCalls, isEmpty);
    });

    testWidgets('a short title is refused', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'ab');

      await save(tester);

      expect(find.text('Use at least 3 characters'), findsOneWidget);
      expect(api.createCalls, isEmpty);
    });

    testWidgets('bad budget and bad link are refused', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');
      await type(tester, 'field-budget', '12.345');
      await type(tester, 'field-link', 'ftp://x.io');

      await save(tester);

      expect(find.text('Use at most 2 decimals'), findsOneWidget);
      expect(
        find.text('Link must start with http:// or https://'),
        findsOneWidget,
      );
      expect(api.createCalls, isEmpty);

      await type(tester, 'field-budget', 'abc');
      await type(tester, 'field-link', 'https://a b.io');
      await save(tester);

      expect(find.text('Enter a number like 1500 or 1500.50'), findsOneWidget);
      expect(find.text('Link must not have spaces'), findsOneWidget);
      expect(api.createCalls, isEmpty);
    });

    testWidgets('a valid form is sent and the screen closes', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', '  Flutter app  ');
      await type(tester, 'field-company', 'Acme');
      await type(tester, 'field-budget', '1500,5');
      await type(tester, 'field-link', 'https://x.io');
      await type(tester, 'field-notes', 'Call on Monday');

      await save(tester);

      expect(api.createCalls, hasLength(1));
      final ProposalDraft sent = api.createCalls.single;
      expect(sent.title.trim(), 'Flutter app');
      expect(sent.company, 'Acme');
      expect(sent.platform, ProposalPlatform.upwork);
      expect(sent.status, ProposalStatus.draft);
      expect(sent.budget, 1500.5);
      expect(sent.followUpDate, isNull);
      expect(sent.link, 'https://x.io');
      expect(sent.notes, 'Call on Monday');
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(ProposalFormScreen), findsNothing);
    });

    testWidgets('a minimal form sends only the title', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'Just a title');

      await save(tester);

      final Map<String, Object?> json = api.createCalls.single.toJson();
      expect(json['title'], 'Just a title');
      expect(json['company'], isNull);
      expect(json['budget'], isNull);
      expect(json['followUpDate'], isNull);
      expect(json['link'], isNull);
      expect(json['notes'], isNull);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('platform and status come from the dropdowns', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await tester.tap(find.byKey(const Key('field-platform')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LinkedIn').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('field-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sent').last);
      await tester.pumpAndSettle();

      await save(tester);

      expect(api.createCalls.single.platform, ProposalPlatform.linkedIn);
      expect(api.createCalls.single.status, ProposalStatus.sent);
    });

    testWidgets('the date picker sets the follow-up date, Clear removes it', (
      tester,
    ) async {
      await openNew(tester);

      await tester.tap(find.byKey(const Key('field-follow-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('6 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('follow-up-clear')), findsOneWidget);

      await tester.tap(find.byKey(const Key('follow-up-clear')));
      await tester.pumpAndSettle();

      expect(find.text('No date'), findsOneWidget);
      expect(find.byKey(const Key('follow-up-clear')), findsNothing);
    });

    testWidgets('the follow-up date is sent as a calendar date', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');
      await tester.tap(find.byKey(const Key('field-follow-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await save(tester);

      expect(api.createCalls.single.followUpDate, CalendarDate(2026, 11, 6));
      expect(api.createCalls.single.toJson()['followUpDate'], '2026-11-06');
    });
  });

  group('server errors', () {
    testWidgets('field errors show under the matching inputs', (tester) async {
      api.createHandler = (ProposalDraft draft) async => const ApiErr<Proposal>(
        ApiError(
          code: ApiErrorCodes.validation,
          message: 'Validation failed.',
          fields: <String, String>{
            'title': 'Title is taken',
            'company': 'Company is not allowed',
            'link': 'Link is not reachable',
          },
        ),
      );
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await save(tester);

      expect(find.text('Title is taken'), findsOneWidget);
      expect(find.text('Company is not allowed'), findsOneWidget);
      expect(find.text('Link is not reachable'), findsOneWidget);
      // All keys are known inputs, so there is no banner.
      expect(find.byKey(const Key('form-error-banner')), findsNothing);
      expect(find.byType(ProposalFormScreen), findsOneWidget);
    });

    testWidgets('an unknown field goes to the banner', (tester) async {
      api.createHandler = (ProposalDraft draft) async => const ApiErr<Proposal>(
        ApiError(
          code: ApiErrorCodes.validation,
          message: 'Validation failed.',
          fields: <String, String>{
            'title': 'Title is taken',
            'mystery': 'Something else is wrong',
          },
        ),
      );
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await save(tester);

      expect(find.text('Title is taken'), findsOneWidget);
      expect(find.text('Something else is wrong'), findsOneWidget);
      expect(find.byKey(const Key('form-error-banner')), findsOneWidget);
    });

    testWidgets('typing in a field removes its server error', (tester) async {
      api.createHandler = (ProposalDraft draft) async => const ApiErr<Proposal>(
        ApiError(
          code: ApiErrorCodes.validation,
          message: 'Validation failed.',
          fields: <String, String>{'title': 'Title is taken'},
        ),
      );
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');
      await save(tester);
      expect(find.text('Title is taken'), findsOneWidget);

      await type(tester, 'field-title', 'Flutter app 2');

      expect(find.text('Title is taken'), findsNothing);
    });

    testWidgets('a new Save clears the old server error', (tester) async {
      int calls = 0;
      api.createHandler = (ProposalDraft draft) async {
        calls++;
        if (calls == 1) {
          return const ApiErr<Proposal>(
            ApiError(
              code: ApiErrorCodes.validation,
              message: 'Validation failed.',
              fields: <String, String>{'company': 'Company is not allowed'},
            ),
          );
        }
        return ApiOk<Proposal>(makeProposal(1));
      };
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');
      await save(tester);
      expect(find.text('Company is not allowed'), findsOneWidget);

      await save(tester);

      expect(calls, 2);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('proposal_limit tells the user to delete one', (tester) async {
      api.createHandler = (ProposalDraft draft) async => const ApiErr<Proposal>(
        ApiError(code: ApiErrorCodes.proposalLimit, message: 'Limit.'),
      );
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await save(tester);

      expect(
        find.textContaining('Delete one to add a new one'),
        findsOneWidget,
      );
      expect(find.byType(ProposalFormScreen), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a network error and a rate limit show a banner', (
      tester,
    ) async {
      api.createHandler = (ProposalDraft draft) async =>
          const ApiErr<Proposal>(ApiError.network());
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await save(tester);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );

      api.createHandler = (ProposalDraft draft) async => const ApiErr<Proposal>(
        ApiError(
          code: ApiErrorCodes.rateLimited,
          message: 'raw',
          retryAfterSeconds: 12,
        ),
      );
      await save(tester);
      expect(
        find.text('Too many requests. Try again in 12 seconds.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('form-error-banner')), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('Save is disabled while saving and sends one request', (
      tester,
    ) async {
      final Completer<ApiResult<Proposal>> gate =
          Completer<ApiResult<Proposal>>();
      api.createHandler = (ProposalDraft draft) => gate.future;
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      expect(saveEnabled(tester), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('save-button')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(api.createCalls, hasLength(1));

      gate.complete(ApiOk<Proposal>(makeProposal(1)));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Save is enabled again after an error', (tester) async {
      api.createHandler = (ProposalDraft draft) async =>
          const ApiErr<Proposal>(ApiError.network());
      await openNew(tester);
      await type(tester, 'field-title', 'Flutter app');

      await save(tester);

      expect(saveEnabled(tester), isTrue);
    });
  });

  group('unsaved changes', () {
    testWidgets('Back with no change closes at once', (tester) async {
      await openNew(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Back with a change asks first. Keep editing stays', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, 'field-title', 'abc');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(ProposalFormScreen), findsOneWidget);
      expect(textOf(tester, 'field-title'), 'abc');
    });

    testWidgets('Discard closes the form and sends nothing', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'abc');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(api.createCalls, isEmpty);
    });

    testWidgets('a change that is undone is not a change', (tester) async {
      await openNew(tester);
      await type(tester, 'field-title', 'abc');
      await type(tester, 'field-title', '');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a changed dropdown or date also asks', (tester) async {
      await openNew(tester);
      await tester.tap(find.byKey(const Key('field-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Won').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('edit proposal', () {
    testWidgets('loads the proposal and fills every input', (tester) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);

      await openEdit(tester);

      expect(api.getIds, <String>[routeTestId]);
      expect(find.text('Edit proposal'), findsOneWidget);
      expect(textOf(tester, 'field-title'), 'Server title');
      expect(textOf(tester, 'field-company'), 'Acme');
      expect(textOf(tester, 'field-budget'), '99.50');
      expect(textOf(tester, 'field-link'), 'https://acme.io/job');
      expect(textOf(tester, 'field-notes'), 'Line one\nLine two');
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Viewed'), findsOneWidget);
      expect(find.text('1 Dec 2026'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('shows a spinner while it loads', (tester) async {
      final Completer<ApiResult<Proposal>> gate =
          Completer<ApiResult<Proposal>>();
      api.getHandler = (String id) => gate.future;

      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('open-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('form-loading')), findsOneWidget);
      expect(find.byKey(const Key('field-title')), findsNothing);

      gate.complete(ApiOk<Proposal>(fullProposal));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field-title')), findsOneWidget);
    });

    testWidgets('Save sends the WHOLE object, not only the change', (
      tester,
    ) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      await openEdit(tester);
      await type(tester, 'field-title', 'New title');

      await save(tester);

      expect(api.updateIds, <String>[routeTestId]);
      expect(
        api.updateDrafts.single,
        ProposalDraft(
          title: 'New title',
          company: 'Acme',
          platform: ProposalPlatform.email,
          status: ProposalStatus.viewed,
          budget: 99.5,
          followUpDate: CalendarDate(2026, 12, 1),
          link: 'https://acme.io/job',
          notes: 'Line one\nLine two',
        ),
      );
      expect(api.createCalls, isEmpty);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('an empty company is sent as null (cleared)', (tester) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      await openEdit(tester);
      await type(tester, 'field-company', '');

      await save(tester);

      expect(api.updateDrafts.single.toJson()['company'], isNull);
    });

    testWidgets('the date can be cleared in an edit', (tester) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      await openEdit(tester);

      await tester.tap(find.byKey(const Key('follow-up-clear')));
      await tester.pumpAndSettle();
      await save(tester);

      expect(api.updateDrafts.single.followUpDate, isNull);
      expect(api.updateDrafts.single.toJson()['followUpDate'], isNull);
    });

    testWidgets('saving without a change asks no question', (tester) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      await openEdit(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('404 on load shows "not found" and a Back button', (
      tester,
    ) async {
      api.getHandler = (String id) async => const ApiErr<Proposal>(
        ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
      );

      await openEdit(tester);

      expect(find.byKey(const Key('form-not-found')), findsOneWidget);
      expect(find.text('Proposal not found.'), findsOneWidget);
      expect(find.byKey(const Key('field-title')), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('another load error shows Retry, and Retry loads again', (
      tester,
    ) async {
      api.getHandler = (String id) async =>
          const ApiErr<Proposal>(ApiError.network());
      await openEdit(tester);

      expect(find.byKey(const Key('form-load-error')), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );

      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(api.getIds, hasLength(2));
      expect(find.byKey(const Key('form-load-error')), findsNothing);
      expect(textOf(tester, 'field-title'), 'Server title');
    });

    testWidgets('404 on save shows a banner and keeps the form', (
      tester,
    ) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      api.updateHandler = (String id, ProposalDraft draft) async =>
          const ApiErr<Proposal>(
            ApiError(code: ApiErrorCodes.notFound, message: 'Not found.'),
          );
      await openEdit(tester);
      await type(tester, 'field-title', 'New title');

      await save(tester);

      expect(find.textContaining('not found'), findsOneWidget);
      expect(find.byKey(const Key('form-error-banner')), findsOneWidget);
      expect(find.byType(ProposalFormScreen), findsOneWidget);
    });

    testWidgets('server field errors show in edit mode too', (tester) async {
      api.getHandler = (String id) async => ApiOk<Proposal>(fullProposal);
      api.updateHandler = (String id, ProposalDraft draft) async =>
          const ApiErr<Proposal>(
            ApiError(
              code: ApiErrorCodes.validation,
              message: 'Validation failed.',
              fields: <String, String>{'budget': 'Budget is too high'},
            ),
          );
      await openEdit(tester);
      await type(tester, 'field-title', 'New title');

      await save(tester);

      expect(find.text('Budget is too high'), findsOneWidget);
      expect(find.byType(ProposalFormScreen), findsOneWidget);
    });
  });
}
