import 'package:apply_track/core/db/app_database.dart';
import 'package:apply_track/features/proposals/data/drift_proposal_cache.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/proposal_fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftProposalCache cache;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    cache = DriftProposalCache(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'a saved first page is read back with the same order and fields',
    () async {
      // Newest first: the higher the number, the newer the id.
      final items = <Proposal>[
        Proposal(
          id: proposalId(3),
          title: 'Flutter app',
          company: 'Acme',
          platform: ProposalPlatform.linkedIn,
          status: ProposalStatus.interview,
          budget: 123.45,
          followUpDate: CalendarDate(2026, 12, 31),
          link: 'https://example.com/job',
          notes: 'Line 1\nLine 2',
          createdAtMs: 1767225600000,
          updatedAtMs: 1767225700000,
        ),
        makeProposal(
          2,
          status: ProposalStatus.won,
          platform: ProposalPlatform.email,
          budget: 500,
        ),
        makeProposal(1),
      ];

      await cache.replaceFirstPage('a', items);

      expect(await cache.firstPage('a'), items);
    },
  );

  test('clearing one user does not delete the rows of another user', () async {
    final rowsOfB = <Proposal>[makeProposal(6), makeProposal(5)];
    await cache.replaceFirstPage('a', <Proposal>[makeProposal(2)]);
    await cache.replaceFirstPage('b', rowsOfB);

    await cache.clearUser('a');

    expect(await cache.firstPage('a'), isEmpty);
    expect(await cache.firstPage('b'), rowsOfB);
  });
}
