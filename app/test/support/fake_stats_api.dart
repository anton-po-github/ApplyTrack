import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/data/stats_api.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';

/// A fake [StatsApi]. Set [handler] to control the answer
/// (use a `Completer` inside it to keep a call "slow").
final class FakeStatsApi implements StatsApi {
  int calls = 0;

  Future<ApiResult<ProposalStats>> Function() handler = () async =>
      const ApiOk<ProposalStats>(ProposalStats.zero);

  @override
  Future<ApiResult<ProposalStats>> getStats() {
    calls++;
    return handler();
  }
}

ProposalStats statsOf({int total = 0, int won = 0, int lost = 0}) =>
    ProposalStats(
      total: total,
      draft: 0,
      sent: 0,
      viewed: 0,
      interview: 0,
      won: won,
      lost: lost,
    );
