import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_field.dart';

/// Pure checks from 07-api-schema.md (section 6). They give a good UX.
/// The server still checks everything again.
///
/// Length is counted in UTF-16 units. The .NET server counts the same way.
/// Every function returns null when the value is fine.
abstract final class ProposalValidators {
  static const int titleMin = 3;
  static const int titleMax = 120;
  static const int companyMax = 120;
  static const int linkMax = 2048;
  static const int notesMax = 4000;
  static const int searchMax = 100;
  static const double budgetMax = 9999999999.99;

  /// Up to 10 digits, then up to 2 decimals (so 0 .. 9,999,999,999.99).
  static final RegExp _budgetPattern = RegExp(r'^\d{1,10}(\.\d{1,2})?$');
  static final RegExp _tooManyDecimals = RegExp(r'^\d+\.\d{3,}$');
  static final RegExp _whitespace = RegExp(r'\s');

  // ---------------------------------------------------------------- title

  static String? title(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Title is required';
    if (text.length < titleMin) return 'Use at least $titleMin characters';
    if (text.length > titleMax) return 'Use at most $titleMax characters';
    if (_hasControlOrLineBreak(text)) return 'Title has invalid characters';
    return null;
  }

  // -------------------------------------------------------------- company

  static String? company(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // Optional.
    if (text.length > companyMax) return 'Use at most $companyMax characters';
    if (_hasControlOrLineBreak(text)) return 'Company has invalid characters';
    return null;
  }

  // --------------------------------------------------------------- budget

  /// The text from the budget input. A comma works like a dot.
  static String normalizeBudgetText(String? value) =>
      (value ?? '').trim().replaceAll(',', '.');

  static String? budget(String? value) {
    final text = normalizeBudgetText(value);
    if (text.isEmpty) return null; // Optional.
    if (text.startsWith('-')) return 'Budget cannot be negative';
    if (_tooManyDecimals.hasMatch(text)) return 'Use at most 2 decimals';
    if (!_budgetPattern.hasMatch(text)) {
      return 'Enter a number like 1500 or 1500.50';
    }
    return null;
  }

  /// Call it only after [budget] returned null.
  /// Gives null for an empty or a bad text.
  static double? parseBudget(String? value) {
    final text = normalizeBudgetText(value);
    if (text.isEmpty || budget(value) != null) return null;
    return double.tryParse(text);
  }

  /// The same rule for a number (used by [draft] before a request).
  static String? budgetValue(double value) {
    if (value.isNaN || value.isInfinite) return 'Enter a valid budget';
    if (value < 0) return 'Budget cannot be negative';
    if (value > budgetMax) return 'Budget is too big';
    // A number has at most 2 decimals when it survives a round trip through
    // 2-decimal text. (A "value * 100" check fails for very big numbers.)
    if (double.parse(value.toStringAsFixed(2)) != value) {
      return 'Use at most 2 decimals';
    }
    return null;
  }

  // ----------------------------------------------------------------- link

  static String? link(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // Optional.
    if (text.length > linkMax) return 'Link is too long';
    final http = text.startsWith('http://');
    final https = text.startsWith('https://');
    if (!http && !https) return 'Link must start with http:// or https://';
    if (text.length == (https ? 8 : 7)) return 'Enter a full link';
    if (_whitespace.hasMatch(text) || _hasControlOrLineBreak(text)) {
      return 'Link must not have spaces';
    }
    return null;
  }

  // ---------------------------------------------------------------- notes

  static String? notes(String? value) {
    final text = value ?? '';
    if (text.length > notesMax) return 'Use at most $notesMax characters';
    for (final unit in text.codeUnits) {
      // Line breaks and tabs are allowed. Other control characters are not.
      if (unit == 0x0A || unit == 0x0D || unit == 0x09) continue;
      if (_isControl(unit)) return 'Notes have invalid characters';
    }
    return null;
  }

  // --------------------------------------------------------------- search

  /// The text for the `q` query. Null means "no search".
  static String? normalizeSearchQuery(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static String? searchQuery(String? value) {
    final text = (value ?? '').trim();
    if (text.length > searchMax) return 'Use at most $searchMax characters';
    if (_hasControlOrLineBreak(text)) return 'Search has invalid characters';
    return null;
  }

  // ---------------------------------------------------------------- draft

  /// Checks a whole draft before we send it. Empty map = all good.
  static Map<ProposalField, String> draft(ProposalDraft value) {
    final errors = <ProposalField, String>{};
    void add(ProposalField field, String? message) {
      if (message != null) errors[field] = message;
    }

    add(ProposalField.title, title(value.title));
    add(ProposalField.company, company(value.company));
    final budget = value.budget;
    if (budget != null) add(ProposalField.budget, budgetValue(budget));
    add(ProposalField.link, link(value.link));
    add(ProposalField.notes, notes(value.notes));
    return Map<ProposalField, String>.unmodifiable(errors);
  }

  // -------------------------------------------------------------- helpers

  static bool _hasControlOrLineBreak(String text) {
    for (final unit in text.codeUnits) {
      // 0x2028 and 0x2029 are Unicode line breaks.
      if (_isControl(unit) || unit == 0x2028 || unit == 0x2029) return true;
    }
    return false;
  }

  static bool _isControl(int unit) =>
      unit <= 0x1F || (unit >= 0x7F && unit <= 0x9F);
}
