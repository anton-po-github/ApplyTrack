import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/data/stats_api.dart';

// Wiring of the real objects. Tests override these providers.

final Provider<ProposalsApi> proposalsApiProvider = Provider<ProposalsApi>(
  (Ref ref) => HttpProposalsApi(ref.watch(apiClientProvider)),
);

final Provider<StatsApi> statsApiProvider = Provider<StatsApi>(
  (Ref ref) => HttpStatsApi(ref.watch(apiClientProvider)),
);
