import 'package:apply_track/features/proposals/domain/proposal_page.dart';
import 'package:apply_track/features/proposals/domain/proposal_stats.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> proposalJson(String id) => <String, Object?>{
  'id': id,
  'title': 'Title $id',
  'company': null,
  'platform': 0,
  'status': 0,
  'budget': null,
  'followUpDate': null,
  'link': null,
  'notes': null,
  'createdAtMs': 1,
  'updatedAtMs': 2,
};

Map<String, Object?> statsJson({int won = 0, int lost = 0}) =>
    <String, Object?>{
      'total': 10 + won + lost,
      'draft': 1,
      'sent': 2,
      'viewed': 3,
      'interview': 4,
      'won': won,
      'lost': lost,
    };

void main() {
  group('ProposalPage.fromJson', () {
    test('reads items and nextCursor', () {
      final page = ProposalPage.fromJson(<String, Object?>{
        'items': <Object?>[proposalJson('b'), proposalJson('a')],
        'nextCursor': 'a',
      });

      expect(page.items.map((p) => p.id), <String>['b', 'a']);
      expect(page.nextCursor, 'a');
      expect(page.hasMore, isTrue);
    });

    test('a null nextCursor means the last page', () {
      final page = ProposalPage.fromJson(<String, Object?>{
        'items': <Object?>[proposalJson('a')],
        'nextCursor': null,
      });

      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('a missing nextCursor and an empty list are fine', () {
      final page = ProposalPage.fromJson(<String, Object?>{
        'items': <Object?>[],
      });

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('the item list cannot be changed', () {
      final page = ProposalPage.fromJson(<String, Object?>{
        'items': <Object?>[proposalJson('a')],
      });

      expect(page.items.clear, throwsUnsupportedError);
    });

    test('throws FormatException on a bad shape', () {
      expect(
        () => ProposalPage.fromJson(<String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => ProposalPage.fromJson(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'a'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => ProposalPage.fromJson(<String, Object?>{
          'items': <Object?>[],
          'nextCursor': 5,
        }),
        throwsFormatException,
      );
    });
  });

  group('ProposalStats', () {
    test('fromJson reads all counters', () {
      final stats = ProposalStats.fromJson(statsJson(won: 2, lost: 3));

      expect(stats.total, 15);
      expect(stats.draft, 1);
      expect(stats.sent, 2);
      expect(stats.viewed, 3);
      expect(stats.interview, 4);
      expect(stats.won, 2);
      expect(stats.lost, 3);
    });

    test('fromJson throws when a counter is missing or wrong', () {
      expect(
        () => ProposalStats.fromJson(statsJson()..remove('lost')),
        throwsFormatException,
      );
      expect(
        () => ProposalStats.fromJson(statsJson()..['won'] = '2'),
        throwsFormatException,
      );
    });

    test('winRate is won / (won + lost)', () {
      expect(ProposalStats.fromJson(statsJson(won: 1, lost: 3)).winRate, 0.25);
      expect(ProposalStats.fromJson(statsJson(won: 2)).winRate, 1.0);
      expect(ProposalStats.fromJson(statsJson(lost: 2)).winRate, 0.0);
    });

    test('winRate is null when nothing is decided', () {
      expect(ProposalStats.fromJson(statsJson()).winRate, isNull);
      expect(ProposalStats.zero.winRate, isNull);
    });

    test('countFor gives the counter of each status', () {
      final stats = ProposalStats.fromJson(statsJson(won: 5, lost: 6));

      expect(stats.countFor(ProposalStatus.draft), 1);
      expect(stats.countFor(ProposalStatus.sent), 2);
      expect(stats.countFor(ProposalStatus.viewed), 3);
      expect(stats.countFor(ProposalStatus.interview), 4);
      expect(stats.countFor(ProposalStatus.won), 5);
      expect(stats.countFor(ProposalStatus.lost), 6);
    });

    test('equal data gives equal stats', () {
      expect(
        ProposalStats.fromJson(statsJson()),
        ProposalStats.fromJson(statsJson()),
      );
      expect(
        ProposalStats.fromJson(statsJson()).hashCode,
        ProposalStats.fromJson(statsJson()).hashCode,
      );
      expect(
        ProposalStats.fromJson(statsJson()),
        isNot(ProposalStats.fromJson(statsJson(won: 1))),
      );
    });
  });
}
