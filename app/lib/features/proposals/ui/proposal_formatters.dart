import 'package:apply_track/features/proposals/domain/calendar_date.dart';

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `1234.5` -> `$1,234.50`, `1200.0` -> `$1,200`.
/// The server stores a number only, so the currency sign is a display choice.
String formatBudget(double value) {
  final bool whole = value == value.roundToDouble();
  final List<String> parts = value.toStringAsFixed(whole ? 0 : 2).split('.');
  final String digits = parts.first;
  final StringBuffer out = StringBuffer(r'$');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(',');
    }
    out.write(digits[i]);
  }
  if (parts.length > 1) {
    out
      ..write('.')
      ..write(parts[1]);
  }
  return out.toString();
}

/// `2026-12-31` -> `31 Dec 2026`. No locale, so it looks the same everywhere.
String formatCalendarDate(CalendarDate date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// The budget as text for an input: `1500` or `1234.50`. No sign, no commas.
String formatBudgetInput(double value) {
  final bool whole = value == value.roundToDouble();
  return value.toStringAsFixed(whole ? 0 : 2);
}
