import 'package:apply_track/features/proposals/data/proposal_cache.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';

/// A fake [ProposalCache] in memory. It follows the same rules as the real
/// cache: newest first (id descending) and at most
/// [ProposalCache.maxItems] rows for each user.
final class FakeProposalCache implements ProposalCache {
  final Map<String, List<Proposal>> _rowsByUser = <String, List<Proposal>>{};

  /// Every user id given to `clearUser`, in call order.
  final List<String> clearedUserIds = <String>[];

  @override
  Future<List<Proposal>> firstPage(String userId) async =>
      List<Proposal>.unmodifiable(_rowsByUser[userId] ?? const <Proposal>[]);

  @override
  Future<void> replaceFirstPage(String userId, List<Proposal> items) async {
    _rowsByUser[userId] = _normalize(items.take(ProposalCache.maxItems));
  }

  @override
  Future<void> upsert(String userId, Proposal proposal) async {
    final rows = _rowsByUser[userId] ?? const <Proposal>[];
    _rowsByUser[userId] = _normalize(<Proposal>[
      ...rows.where((row) => row.id != proposal.id),
      proposal,
    ]);
  }

  @override
  Future<void> remove(String userId, String id) async {
    final rows = _rowsByUser[userId];
    if (rows == null) {
      return;
    }
    _rowsByUser[userId] = rows
        .where((row) => row.id != id)
        .toList(growable: false);
  }

  @override
  Future<void> clearUser(String userId) async {
    clearedUserIds.add(userId);
    _rowsByUser.remove(userId);
  }

  static List<Proposal> _normalize(Iterable<Proposal> items) {
    final sorted = items.toList()..sort((a, b) => b.id.compareTo(a.id));
    return sorted.take(ProposalCache.maxItems).toList(growable: false);
  }
}
