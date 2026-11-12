import 'package:drift/drift.dart';

/// Local copy of the proposals. The server is the truth. This table is only a
/// cache, so it can always be deleted and filled again from the server.
///
/// The list order is `id` descending (ids are UUID v7, so newest first).
/// The index `(userId, id)` makes the first page one index seek plus a short
/// read of a fixed page size.
@DataClassName('CachedProposalRow')
@TableIndex(name: 'cached_proposals_user_id_id', columns: {#userId, #id})
class CachedProposals extends Table {
  TextColumn get id => text()();

  /// The signed-in user who owns the row. Every read must filter by it.
  TextColumn get userId => text()();

  TextColumn get title => text()();

  TextColumn get company => text().nullable()();

  /// `ProposalPlatform.apiValue`.
  IntColumn get platform => integer()();

  /// `ProposalStatus.apiValue`.
  IntColumn get status => integer()();

  RealColumn get budget => real().nullable()();

  /// `yyyy-MM-dd` (the same text the server uses).
  TextColumn get followUpDate => text().nullable()();

  TextColumn get link => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Unix time in MILLISECONDS.
  IntColumn get createdAtMs => integer()();

  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
