import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

import '../../../support/fake_api_client.dart';

const String id = '0190a1b2-0000-7000-8000-000000000001';

Map<String, Object?> proposalJson([String proposalId = id]) =>
    <String, Object?>{
      'id': proposalId,
      'title': 'Flutter app',
      'company': null,
      'platform': 0,
      'status': 1,
      'budget': null,
      'followUpDate': null,
      'link': null,
      'notes': null,
      'createdAtMs': 1,
      'updatedAtMs': 2,
    };

ProposalDraft draft() => ProposalDraft(
  title: '  Flutter app ',
  company: ' ',
  platform: ProposalPlatform.upwork,
  status: ProposalStatus.sent,
  budget: 100,
  followUpDate: CalendarDate(2026, 12, 31),
);

ApiError errorOf<T>(ApiResult<T> result) => (result as ApiErr<T>).error;

void main() {
  late FakeApiClient client;
  late HttpProposalsApi api;

  setUp(() {
    client = FakeApiClient();
    api = HttpProposalsApi(client);
  });

  group('list', () {
    setUp(() {
      client.json = <String, Object?>{
        'items': <Object?>[proposalJson()],
        'nextCursor': 'next-1',
      };
    });

    test('GET /api/proposals with only the default limit', () async {
      final ApiResult<ProposalPage> r = await api.list();

      expect(client.last.method, 'GET');
      expect(client.last.path, '/api/proposals');
      expect(client.last.requiresAuth, isTrue);
      expect(client.last.query, <String, Object?>{
        'status': null,
        'q': null,
        'cursor': null,
        'limit': 20,
      });
      final ProposalPage page = (r as ApiOk<ProposalPage>).value;
      expect(page.items.single.id, id);
      expect(page.nextCursor, 'next-1');
    });

    test('sends status as a number, q and cursor', () async {
      await api.list(
        status: ProposalStatus.interview,
        q: '  flutter ',
        cursor: 'abc',
        limit: 30,
      );

      expect(client.last.query, <String, Object?>{
        'status': 3,
        'q': 'flutter',
        'cursor': 'abc',
        'limit': 30,
      });
    });

    test('a blank q and an empty cursor are not sent', () async {
      await api.list(q: '   ', cursor: '');

      expect(client.last.query!['q'], isNull);
      expect(client.last.query!['cursor'], isNull);
    });

    test('limit stays between 1 and 50', () async {
      await api.list(limit: 0);
      expect(client.last.query!['limit'], 1);

      await api.list(limit: -5);
      expect(client.last.query!['limit'], 1);

      await api.list(limit: 99);
      expect(client.last.query!['limit'], 50);

      await api.list(limit: 50);
      expect(client.last.query!['limit'], 50);
    });

    test('passes an API error through', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.unauthorized,
        message: 'Please sign in again.',
      );

      expect(errorOf(await api.list()).code, ApiErrorCodes.unauthorized);
    });
  });

  group('get', () {
    test('GET /api/proposals/{id}', () async {
      client.json = proposalJson();

      final ApiResult<Proposal> r = await api.get(id);

      expect(client.last.method, 'GET');
      expect(client.last.path, '/api/proposals/$id');
      expect(client.last.requiresAuth, isTrue);
      expect((r as ApiOk<Proposal>).value.title, 'Flutter app');
    });

    test('not_found comes back as an error', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.notFound,
        message: 'Not found.',
      );

      expect(errorOf(await api.get(id)).code, ApiErrorCodes.notFound);
    });

    test('a bad id sends nothing and gives bad_request', () async {
      for (final String bad in <String>[
        '',
        'abc',
        '../auth/me',
        '$id/../x',
        '$id?x=1',
        '$id ',
        '0190a1b2-0000-7000-8000-00000000000g',
      ]) {
        final ApiResult<Proposal> r = await api.get(bad);
        expect(errorOf(r).code, ApiErrorCodes.badRequest, reason: bad);
      }
      expect(client.calls, isEmpty);
    });
  });

  group('create', () {
    test('POST /api/proposals with all 8 keys', () async {
      client.json = proposalJson();

      final ApiResult<Proposal> r = await api.create(draft());

      expect(client.last.method, 'POST');
      expect(client.last.path, '/api/proposals');
      expect(client.last.requiresAuth, isTrue);
      expect(client.last.body, <String, Object?>{
        'title': 'Flutter app',
        'company': null,
        'platform': 0,
        'status': 1,
        'budget': 100.0,
        'followUpDate': '2026-12-31',
        'link': null,
        'notes': null,
      });
      expect(r, isA<ApiOk<Proposal>>());
    });

    test('validation errors keep their fields', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.validation,
        message: 'Please fix the fields.',
        fields: <String, String>{'title': 'Title is required.'},
      );

      final ApiError e = errorOf(await api.create(draft()));

      expect(e.code, ApiErrorCodes.validation);
      expect(e.fields, <String, String>{'title': 'Title is required.'});
    });

    test('proposal_limit comes back as an error', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.proposalLimit,
        message: 'Limit reached.',
      );

      expect(errorOf(await api.create(draft())).code, 'proposal_limit');
    });
  });

  group('update', () {
    test('PUT /api/proposals/{id} with all 8 keys', () async {
      client.json = proposalJson();

      final ApiResult<Proposal> r = await api.update(id, draft());

      expect(client.last.method, 'PUT');
      expect(client.last.path, '/api/proposals/$id');
      expect(client.last.requiresAuth, isTrue);
      expect(client.last.body!.keys, hasLength(8));
      expect(client.last.body!['title'], 'Flutter app');
      expect(r, isA<ApiOk<Proposal>>());
    });

    test('a bad id sends nothing and gives bad_request', () async {
      final ApiResult<Proposal> r = await api.update('nope', draft());

      expect(errorOf(r).code, ApiErrorCodes.badRequest);
      expect(client.calls, isEmpty);
    });

    test('not_found comes back as an error', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.notFound,
        message: 'Not found.',
      );

      expect(errorOf(await api.update(id, draft())).code, 'not_found');
    });
  });

  group('delete', () {
    test('DELETE /api/proposals/{id}', () async {
      final ApiResult<void> r = await api.delete(id);

      expect(client.last.method, 'DELETE');
      expect(client.last.path, '/api/proposals/$id');
      expect(client.last.requiresAuth, isTrue);
      expect(r, isA<ApiOk<void>>());
    });

    test('not_found (second delete) comes back as an error', () async {
      client.error = const ApiError(
        code: ApiErrorCodes.notFound,
        message: 'Not found.',
      );

      expect(errorOf(await api.delete(id)).code, ApiErrorCodes.notFound);
    });

    test('a bad id sends nothing and gives bad_request', () async {
      final ApiResult<void> r = await api.delete('../x');

      expect(errorOf(r).code, ApiErrorCodes.badRequest);
      expect(client.calls, isEmpty);
    });
  });
}
