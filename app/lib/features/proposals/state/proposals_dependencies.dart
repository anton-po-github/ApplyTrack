import 'dart:async';

import 'package:apply_track/core/links/external_link_opener.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/data/stats_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Wiring of the real objects. Tests override these providers.

final Provider<ProposalsApi> proposalsApiProvider = Provider<ProposalsApi>(
  (ref) => HttpProposalsApi(ref.watch(apiClientProvider)),
);

final Provider<StatsApi> statsApiProvider = Provider<StatsApi>(
  (ref) => HttpStatsApi(ref.watch(apiClientProvider)),
);

/// Opens links in the system browser. Tests replace it with a fake.
final Provider<ExternalLinkOpener> externalLinkOpenerProvider =
    Provider<ExternalLinkOpener>((ref) => const UrlLauncherLinkOpener());

/// The id of the signed-in user. Null in every other auth state.
/// Proposal state watches it, so another user never sees old data.
final Provider<String?> currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn ? auth.user.id : null;
});

/// Makes the search debounce timer. Tests replace it with a fake.
typedef DebounceTimerFactory = Timer Function(
  Duration delay,
  void Function() onFire,
);

final Provider<DebounceTimerFactory> debounceTimerFactoryProvider =
    Provider<DebounceTimerFactory>((ref) => Timer.new);

final Provider<Duration> searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// Counts the successful writes (create, update, delete).
/// The list controller raises it. The stats state (Step 6) listens to it.
/// Only the change matters.
final NotifierProvider<ProposalsChangedSignal, int> proposalsChangedProvider =
    NotifierProvider<ProposalsChangedSignal, int>(ProposalsChangedSignal.new);

class ProposalsChangedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}
