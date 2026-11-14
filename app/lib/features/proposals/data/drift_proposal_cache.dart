import 'package:apply_track/core/db/app_database.dart';
import 'package:apply_track/features/proposals/data/proposal_cache.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:drift/drift.dart';

/// [ProposalCache] on top of the local Drift database.
/// Every query filters by `userId`. A multi-step write runs in one
/// transaction, so the cache is never half written.
final class DriftProposalCache implements ProposalCache {
  const new(this._database);

  final AppDatabase _database;

  @override
  Future<List<Proposal>> firstPage(String userId) async {
    final query = _database.select(_database.cachedProposals)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(ProposalCache.maxItems);
    final rows = await query.get();
    try {
      return List<Proposal>.unmodifiable(rows.map(_toProposal));
    } on FormatException {
      // A broken row (for example an unknown status) means we cannot trust
      // this copy. We answer "nothing saved"; the server is the truth.
      return const <Proposal>[];
    }
  }

  /// [items] must come newest first, like the server sends them.
  @override
  Future<void> replaceFirstPage(String userId, List<Proposal> items) async {
    final companions = items
        .take(ProposalCache.maxItems)
        .map((proposal) => _toCompanion(userId, proposal))
        .toList(growable: false);
    await _database.transaction(() async {
      await (_database.delete(
        _database.cachedProposals,
      )..where((t) => t.userId.equals(userId))).go();
      await _database.batch((batch) {
        batch.insertAll(
          _database.cachedProposals,
          companions,
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  @override
  Future<void> upsert(String userId, Proposal proposal) async {
    await _database.transaction(() async {
      await _database
          .into(_database.cachedProposals)
          .insert(
            _toCompanion(userId, proposal),
            mode: InsertMode.insertOrReplace,
          );
      await _trimToMax(userId);
    });
  }

  @override
  Future<void> remove(String userId, String id) async {
    await (_database.delete(
      _database.cachedProposals,
    )..where((t) => t.userId.equals(userId) & t.id.equals(id))).go();
  }

  @override
  Future<void> clearUser(String userId) async {
    await (_database.delete(
      _database.cachedProposals,
    )..where((t) => t.userId.equals(userId))).go();
  }

  /// Deletes the rows of [userId] after position [ProposalCache.maxItems].
  /// Call it inside a transaction. After one insert there is at most one
  /// extra row, so this reads and deletes a fixed small amount.
  Future<void> _trimToMax(String userId) async {
    final query = _database.select(_database.cachedProposals)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(ProposalCache.maxItems, offset: ProposalCache.maxItems);
    final extraIds = (await query.get())
        .map((row) => row.id)
        .toList(growable: false);
    if (extraIds.isEmpty) {
      return;
    }
    await (_database.delete(
      _database.cachedProposals,
    )..where((t) => t.userId.equals(userId) & t.id.isIn(extraIds))).go();
  }

  static CachedProposalsCompanion _toCompanion(
    String userId,
    Proposal proposal,
  ) => CachedProposalsCompanion.insert(
    id: proposal.id,
    userId: userId,
    title: proposal.title,
    company: Value(proposal.company),
    platform: proposal.platform.apiValue,
    status: proposal.status.apiValue,
    budget: Value(proposal.budget),
    followUpDate: Value(proposal.followUpDate?.toApiString()),
    link: Value(proposal.link),
    notes: Value(proposal.notes),
    createdAtMs: proposal.createdAtMs,
    updatedAtMs: proposal.updatedAtMs,
  );

  /// Throws [FormatException] when the row has a value we do not know.
  static Proposal _toProposal(CachedProposalRow row) {
    final followUp = row.followUpDate;
    return Proposal(
      id: row.id,
      title: row.title,
      company: row.company,
      platform: ProposalPlatform.fromApi(row.platform),
      status: ProposalStatus.fromApi(row.status),
      budget: row.budget,
      followUpDate: followUp == null ? null : CalendarDate.parse(followUp),
      link: row.link,
      notes: row.notes,
      createdAtMs: row.createdAtMs,
      updatedAtMs: row.updatedAtMs,
    );
  }
}
