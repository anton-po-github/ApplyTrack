import 'package:apply_track/core/db/cached_proposals.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The local database. It does not know how it is opened: the app passes
/// `driftDatabase(...)`, tests pass `NativeDatabase.memory()`.
@DriftDatabase(tables: [CachedProposals])
final class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 1;
}
