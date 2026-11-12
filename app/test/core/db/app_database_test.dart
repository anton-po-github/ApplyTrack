import 'package:apply_track/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('a saved proposal is read back with all its fields', () async {
    const row = CachedProposalRow(
      id: '0190a1b2-0000-7000-8000-000000000001',
      userId: 'user-1',
      title: 'Flutter app',
      company: 'Acme',
      platform: 1,
      status: 3,
      budget: 123.45,
      followUpDate: '2026-12-31',
      link: 'https://example.com/job',
      notes: 'Line 1\nLine 2',
      createdAtMs: 1767225600000,
      updatedAtMs: 1767225700000,
    );

    await database.into(database.cachedProposals).insert(row);
    final rows = await database.select(database.cachedProposals).get();

    expect(rows, <CachedProposalRow>[row]);
  });
}
