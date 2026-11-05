import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/data/stats_api.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';

import '../../../support/fake_api_client.dart';

void main() {
  late FakeApiClient client;
  late HttpStatsApi api;

  setUp(() {
    client = FakeApiClient();
    api = HttpStatsApi(client);
  });

  test('GET /api/stats with auth and a parsed result', () async {
    client.json = <String, Object?>{
      'total': 6,
      'draft': 1,
      'sent': 1,
      'viewed': 1,
      'interview': 1,
      'won': 1,
      'lost': 1,
    };

    final ApiResult<ProposalStats> r = await api.getStats();

    expect(client.last.method, 'GET');
    expect(client.last.path, '/api/stats');
    expect(client.last.requiresAuth, isTrue);
    final ProposalStats stats = (r as ApiOk<ProposalStats>).value;
    expect(stats.total, 6);
    expect(stats.winRate, 0.5);
  });

  test('an API error comes back as an error', () async {
    client.error = const ApiError(
      code: ApiErrorCodes.unauthorized,
      message: 'Please sign in again.',
    );

    final ApiResult<ProposalStats> r = await api.getStats();

    expect((r as ApiErr<ProposalStats>).error.code, 'unauthorized');
  });
}
