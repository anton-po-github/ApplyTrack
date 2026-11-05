import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/proposals/data/proposals_api.dart';
import 'package:apply_track/features/proposals/data/stats_api.dart';

// Wiring of the real objects. Tests override these providers.

final Provider<ProposalsApi> proposalsApiProvider = Provider<ProposalsApi>(
  (Ref ref) => HttpProposalsApi(ref.watch(apiClientProvider)),
);

final Provider<StatsApi> statsApiProvider = Provider<StatsApi>(
  (Ref ref) => HttpStatsApi(ref.watch(apiClientProvider)),
);

/// The id of the signed-in user. Null in every other auth state.
/// Proposal state watches it, so another user never sees old data.
final Provider<String?> currentUserIdProvider = Provider<String?>((Ref ref) {
  final AuthState auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn ? auth.user.id : null;
});

/// Makes the search debounce timer. Tests replace it with a fake.
typedef DebounceTimerFactory = Timer Function(
  Duration delay,
  void Function() onFire,
);

final Provider<DebounceTimerFactory> debounceTimerFactoryProvider =
    Provider<DebounceTimerFactory>(
      (Ref ref) =>
          (Duration delay, void Function() onFire) => Timer(delay, onFire),
    );

final Provider<Duration> searchDebounceProvider = Provider<Duration>(
  (Ref ref) => const Duration(milliseconds: 400),
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
