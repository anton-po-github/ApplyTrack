import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> fullJson() => <String, Object?>{
  'id': '0190a1b2-0000-7000-8000-000000000001',
  'title': 'Flutter app',
  'company': 'Acme',
  'platform': 1,
  'status': 3,
  'budget': 123.45,
  'followUpDate': '2026-12-31',
  'link': 'https://example.com/job',
  'notes': 'Line 1\nLine 2',
  'createdAtMs': 1767225600000,
  'updatedAtMs': 1767225700000,
};

void main() {
  group('Proposal.fromJson', () {
    test('reads all fields', () {
      final p = Proposal.fromJson(fullJson());

      expect(p.id, '0190a1b2-0000-7000-8000-000000000001');
      expect(p.title, 'Flutter app');
      expect(p.company, 'Acme');
      expect(p.platform, ProposalPlatform.linkedIn);
      expect(p.status, ProposalStatus.interview);
      expect(p.budget, 123.45);
      expect(p.followUpDate, CalendarDate(2026, 12, 31));
      expect(p.link, 'https://example.com/job');
      expect(p.notes, 'Line 1\nLine 2');
      expect(p.createdAtMs, 1767225600000);
      expect(p.updatedAtMs, 1767225700000);
    });

    test('the optional fields can be null', () {
      final json = fullJson()
        ..['company'] = null
        ..['budget'] = null
        ..['followUpDate'] = null
        ..['link'] = null
        ..['notes'] = null;

      final p = Proposal.fromJson(json);

      expect(p.company, isNull);
      expect(p.budget, isNull);
      expect(p.followUpDate, isNull);
      expect(p.link, isNull);
      expect(p.notes, isNull);
    });

    test('the optional fields can be missing', () {
      final json = fullJson()
        ..remove('company')
        ..remove('budget')
        ..remove('followUpDate')
        ..remove('link')
        ..remove('notes');

      expect(Proposal.fromJson(json).budget, isNull);
    });

    test('budget as a whole number becomes a double', () {
      final p = Proposal.fromJson(fullJson()..['budget'] = 100);
      expect(p.budget, 100.0);
      expect(p.budget, isA<double>());
    });

    test('budget 0 is kept (it is not null)', () {
      expect(Proposal.fromJson(fullJson()..['budget'] = 0).budget, 0.0);
    });

    test('createdAt and updatedAt use milliseconds', () {
      final p = Proposal.fromJson(fullJson());
      expect(p.createdAt, DateTime.fromMillisecondsSinceEpoch(1767225600000));
      expect(p.updatedAt, DateTime.fromMillisecondsSinceEpoch(1767225700000));
    });

    test('throws FormatException on a bad status or platform', () {
      expect(
        () => Proposal.fromJson(fullJson()..['status'] = 9),
        throwsFormatException,
      );
      expect(
        () => Proposal.fromJson(fullJson()..['platform'] = -1),
        throwsFormatException,
      );
    });

    test('throws FormatException on a wrong type', () {
      expect(
        () => Proposal.fromJson(fullJson()..['budget'] = '12'),
        throwsFormatException,
      );
      expect(
        () => Proposal.fromJson(fullJson()..['title'] = 5),
        throwsFormatException,
      );
      expect(
        () => Proposal.fromJson(fullJson()..['status'] = '1'),
        throwsFormatException,
      );
      expect(
        () => Proposal.fromJson(fullJson()..['createdAtMs'] = '1'),
        throwsFormatException,
      );
    });

    test('throws FormatException on a bad date', () {
      expect(
        () => Proposal.fromJson(fullJson()..['followUpDate'] = '31.12.2026'),
        throwsFormatException,
      );
    });

    test('throws FormatException when a required key is missing', () {
      for (final key in <String>[
        'id',
        'title',
        'platform',
        'status',
        'createdAtMs',
        'updatedAtMs',
      ]) {
        expect(
          () => Proposal.fromJson(fullJson()..remove(key)),
          throwsFormatException,
          reason: key,
        );
      }
    });
  });

  test('equal data gives equal proposals', () {
    expect(Proposal.fromJson(fullJson()), Proposal.fromJson(fullJson()));
    expect(
      Proposal.fromJson(fullJson()).hashCode,
      Proposal.fromJson(fullJson()).hashCode,
    );
    expect(
      Proposal.fromJson(fullJson()),
      isNot(Proposal.fromJson(fullJson()..['title'] = 'Other')),
    );
  });
}
