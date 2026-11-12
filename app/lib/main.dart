import 'package:apply_track/app.dart';
//import 'package:apply_track/core/db/app_database_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: AppRoot()));
}

/* Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final db = container.read(appDatabaseProvider);
  final rows = await db.select(db.cachedProposals).get();
  debugPrint('DB OPEN, rows: ${rows.length}');
  runApp(
    UncontrolledProviderScope(container: container, child: const AppRoot()),
  );
} */
