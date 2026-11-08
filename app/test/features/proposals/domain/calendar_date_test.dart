import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse', () {
    test('reads yyyy-MM-dd', () {
      final date = CalendarDate.parse('2026-12-31');
      expect(date.year, 2026);
      expect(date.month, 12);
      expect(date.day, 31);
    });

    test('accepts a leap day only in a leap year', () {
      expect(CalendarDate.parse('2028-02-29').day, 29);
      expect(() => CalendarDate.parse('2027-02-29'), throwsFormatException);
    });

    test('rejects other formats', () {
      for (final bad in <String>[
        '',
        '2026-2-3',
        '2026/12/31',
        '31-12-2026',
        '2026-12-31T00:00:00',
        '2026-12-31Z',
        ' 2026-12-31',
        '2026-12-31\n',
        '2026-13-01',
        '2026-00-10',
        '2026-04-31',
        'abcd-ef-gh',
      ]) {
        expect(
          () => CalendarDate.parse(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('toApiString', () {
    test('pads month and day with zeros', () {
      expect(CalendarDate(2026, 3, 5).toApiString(), '2026-03-05');
    });

    test('round trip', () {
      expect(CalendarDate.parse('2026-12-31').toApiString(), '2026-12-31');
    });
  });

  group('conversion', () {
    test('fromDateTime ignores time', () {
      expect(
        CalendarDate.fromDateTime(DateTime(2026, 7, 4, 23, 59, 59)),
        CalendarDate(2026, 7, 4),
      );
    });

    test('toDateTime is local midnight', () {
      expect(CalendarDate(2026, 7, 4).toDateTime(), DateTime(2026, 7, 4));
    });

    test('the constructor rejects a date that does not exist', () {
      expect(() => CalendarDate(2026, 2, 30), throwsArgumentError);
    });
  });

  group('compare and equality', () {
    test('isBefore and compareTo', () {
      final a = CalendarDate(2026, 1, 31);
      final b = CalendarDate(2026, 2, 1);
      expect(a.isBefore(b), isTrue);
      expect(b.isBefore(a), isFalse);
      expect(a.isBefore(a), isFalse);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(CalendarDate(2026, 1, 31)), 0);
    });

    test('equal dates have equal hash codes', () {
      expect(CalendarDate(2026, 5, 1), CalendarDate(2026, 5, 1));
      expect(
        CalendarDate(2026, 5, 1).hashCode,
        CalendarDate(2026, 5, 1).hashCode,
      );
      expect(CalendarDate(2026, 5, 1), isNot(CalendarDate(2026, 5, 2)));
    });
  });
}
