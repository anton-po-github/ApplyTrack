import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';

/// `GET /api/stats` (endpoint 5 in 07). One row on the server, so it is fast.
abstract interface class StatsApi {
  Future<ApiResult<ProposalStats>> getStats();
}

final class HttpStatsApi implements StatsApi {
  const HttpStatsApi(this._client);

  final ApiClient _client;

  @override
  Future<ApiResult<ProposalStats>> getStats() =>
      _client.get<ProposalStats>('/api/stats', parse: ProposalStats.fromJson);
}
