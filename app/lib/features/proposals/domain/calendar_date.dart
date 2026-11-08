import 'package:meta/meta.dart';

/// A date without time and without time zone (like `2026-12-31`).
/// The server uses `yyyy-MM-dd` for `followUpDate`. A plain DateTime would
/// bring time zone bugs, so we do not use it for this field.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// Throws [ArgumentError] when the date does not exist (for example Feb 30).
  factory(int year, int month, int day) {
    if (!_exists(year, month, day)) {
      throw ArgumentError('This date does not exist');
    }
    return CalendarDate._(year, month, day);
  }

  const new _(this.year, this.month, this.day);

  /// Takes the year, month and day of [value]. Time and zone are ignored.
  factory fromDateTime(DateTime value) =>
      CalendarDate(value.year, value.month, value.day);

  /// Strict: exactly `yyyy-MM-dd`. Anything else throws [FormatException].
  factory parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw const FormatException('Expected a date as yyyy-MM-dd');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (!_exists(year, month, day)) {
      throw const FormatException('This date does not exist');
    }
    return CalendarDate._(year, month, day);
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// True when the date is real (Feb 30 is not).
  static bool _exists(int year, int month, int day) {
    final check = DateTime.utc(year, month, day);
    return check.year == year && check.month == month && check.day == day;
  }

  final int year;
  final int month;
  final int day;

  /// The text for the server: `yyyy-MM-dd`.
  String toApiString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Local midnight. Use it for the date picker.
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toApiString();
}
