import 'package:apply_track/features/proposals/domain/proposal.dart';

/// Local copy of the first page of proposals, for reading without network.
/// The server is the truth. This cache can always be cleared and filled again.
///
/// Rules for every implementation:
/// - Every method works for one "userId" only. It never reads or changes the
///   rows of another user.
/// - The order is newest first (id descending), the same as the server.
/// - A user never has more than [maxItems] rows.
/// - A method can throw when the storage fails. The caller must catch it and
///   go on without the cache.
abstract interface class ProposalCache {
  /// The most rows we keep for one user.
  static const int maxItems = 50;

  /// The saved first page of [userId]. An empty list means "nothing saved".
  Future<List<Proposal>> firstPage(String userId);

  /// Replaces all rows of [userId] with [items] in one step. It never leaves
  /// a half written cache. Only the first [maxItems] items are kept.
  Future<void> replaceFirstPage(String userId, List<Proposal> items);

  /// Saves one proposal. It replaces the row with the same id.
  /// The cap of [maxItems] still holds after the call.
  Future<void> upsert(String userId, Proposal proposal);

  /// Deletes one proposal of [userId]. A missing id is not an error.
  Future<void> remove(String userId, String id);

  /// Deletes all rows of [userId] (sign out, or a 401 answer).
  Future<void> clearUser(String userId);
}
