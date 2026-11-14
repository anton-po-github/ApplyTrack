import 'dart:async';

import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deletes the saved list of a user when this user leaves: sign out, a 401
/// answer, or another user who signs in. The next person on this device must
/// not see old data.
///
/// It listens to [currentUserIdProvider]. A listener gets the OLD value, so
/// we know whose rows to delete, even though the current id is already null.
/// The app root watches this provider, so it is alive for the whole run.
///
/// The first sign in (old id is null) deletes nothing. A storage error is
/// ignored: the cache is optional.
final Provider<void> proposalCacheCleanerProvider = Provider<void>((ref) {
  ref.listen<String?>(currentUserIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      unawaited(_clearUser(ref, previous));
    }
  });
});

Future<void> _clearUser(Ref ref, String userId) async {
  if (!ref.mounted) {
    return;
  }
  try {
    await ref.read(proposalCacheProvider).clearUser(userId);
  } on Exception {
    // The cache is optional. Nothing more we can do.
  }
}
