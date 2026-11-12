import 'package:apply_track/core/db/app_database.dart';
// import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _databaseName = 'apply_track';

/// The real database. It opens on the first query, so a storage problem
/// (for example a browser that blocks storage) never stops the app from
/// starting. Tests replace this provider with an in-memory database.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(
    driftDatabase(
      name: _databaseName,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
  ref.onDispose(database.close);
  return database;
});
