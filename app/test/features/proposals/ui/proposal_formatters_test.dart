import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/ui/proposal_formatters.dart';

void main() {
  group('formatBudget', () {
    test('whole numbers have no decimals', () {
      expect(formatBudget(0), r'$0');
      expect(formatBudget(5), r'$5');
      expect(formatBudget(999), r'$999');
      expect(formatBudget(1200), r'$1,200');
    });

    test('other numbers have 2 decimals', () {
      expect(formatBudget(1234.5), r'$1,234.50');
      expect(formatBudget(0.99), r'$0.99');
      expect(formatBudget(12.05), r'$12.05');
    });

    test('groups of three digits', () {
      expect(formatBudget(1000), r'$1,000');
      expect(formatBudget(123456), r'$123,456');
      expect(formatBudget(1234567), r'$1,234,567');
      expect(formatBudget(9999999999.99), r'$9,999,999,999.99');
    });
  });

  group('formatCalendarDate', () {
    test('uses day, short month and year', () {
      expect(formatCalendarDate(CalendarDate(2026, 12, 31)), '31 Dec 2026');
      expect(formatCalendarDate(CalendarDate(2026, 1, 5)), '5 Jan 2026');
    });

    test('every month has its own name', () {
      final List<String> names = <String>[
        for (int m = 1; m <= 12; m++)
          formatCalendarDate(CalendarDate(2026, m, 1)).split(' ')[1],
      ];
      expect(names.toSet(), hasLength(12));
      expect(names.first, 'Jan');
      expect(names.last, 'Dec');
    });
  });
}
