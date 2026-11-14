import 'package:apply_track/features/proposals/state/proposal_cache_cleaner.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_proposal_cache.dart';
import '../../../support/proposal_fixtures.dart';

/// A user id that the test can change, like a sign in or a sign out.
class _TestUserId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final NotifierProvider<_TestUserId, String?> _testUserIdProvider =
    NotifierProvider<_TestUserId, String?>(_TestUserId.new);

void main() {
  test('deletes the rows of the user who left, never of the new one', () async {
    final cache = FakeProposalCache();
    await cache.replaceFirstPage('u1', [makeProposal(1)]);
    await cache.replaceFirstPage('u2', [makeProposal(2)]);
    final container = ProviderContainer(
      overrides: [
        proposalCacheProvider.overrideWithValue(cache),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(_testUserIdProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The app root watches it like this.
    container.listen<void>(proposalCacheCleanerProvider, (previous, next) {});
    final user = container.read(_testUserIdProvider.notifier);

    // First sign in: nobody left.
    user.set('u1');
    await pumpEventQueue();
    expect(cache.clearedUserIds, isEmpty);

    // Sign out or a 401 answer: the current id is null, the old id is known.
    user.set(null);
    await pumpEventQueue();
    expect(cache.clearedUserIds, ['u1']);
    expect(await cache.firstPage('u1'), isEmpty);
    expect(await cache.firstPage('u2'), isNotEmpty);

    // Another user signs in, and then a third one replaces them.
    user.set('u2');
    await pumpEventQueue();
    expect(cache.clearedUserIds, ['u1']);
    user.set('u3');
    await pumpEventQueue();
    expect(cache.clearedUserIds, ['u1', 'u2']);
    expect(await cache.firstPage('u2'), isEmpty);
  });
}
