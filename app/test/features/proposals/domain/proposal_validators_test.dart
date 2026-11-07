import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_field.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_validators.dart';

String rep(int count) => 'a' * count;

void main() {
  group('title', () {
    test('required', () {
      expect(ProposalValidators.title(null), isNotNull);
      expect(ProposalValidators.title(''), isNotNull);
      expect(ProposalValidators.title('     '), isNotNull);
    });

    test('3 to 120 characters', () {
      expect(ProposalValidators.title(rep(2)), isNotNull);
      expect(ProposalValidators.title(rep(3)), isNull);
      expect(ProposalValidators.title(rep(120)), isNull);
      expect(ProposalValidators.title(rep(121)), isNotNull);
    });

    test('counts the trimmed text', () {
      expect(ProposalValidators.title('  ab  '), isNotNull);
      expect(ProposalValidators.title('  abc  '), isNull);
    });

    test('no line breaks or control characters inside', () {
      expect(ProposalValidators.title('ab\ncd'), isNotNull);
      expect(ProposalValidators.title('ab\tcd'), isNotNull);
      expect(ProposalValidators.title('ab\u0000cd'), isNotNull);
      expect(ProposalValidators.title('ab\u2028cd'), isNotNull);
    });

    test('accepts normal Unicode text', () {
      expect(ProposalValidators.title('Розробка застосунку'), isNull);
    });
  });

  group('company', () {
    test('optional', () {
      expect(ProposalValidators.company(null), isNull);
      expect(ProposalValidators.company('   '), isNull);
    });

    test('max 120 and no line breaks', () {
      expect(ProposalValidators.company(rep(120)), isNull);
      expect(ProposalValidators.company(rep(121)), isNotNull);
      expect(ProposalValidators.company('A\nB'), isNotNull);
    });
  });

  group('budget text', () {
    test('optional', () {
      expect(ProposalValidators.budget(null), isNull);
      expect(ProposalValidators.budget('  '), isNull);
    });

    test('accepts whole numbers and up to 2 decimals', () {
      for (final String ok in <String>[
        '0',
        '1500',
        '1500.5',
        '1500.50',
        ' 12.34 ',
        '9999999999',
        '9999999999.99',
      ]) {
        expect(ProposalValidators.budget(ok), isNull, reason: ok);
      }
    });

    test('a comma works like a dot', () {
      expect(ProposalValidators.budget('12,5'), isNull);
      expect(ProposalValidators.parseBudget('12,5'), 12.5);
    });

    test('rejects more than 2 decimals', () {
      expect(ProposalValidators.budget('1.999'), 'Use at most 2 decimals');
      expect(ProposalValidators.budget('1,001'), 'Use at most 2 decimals');
    });

    test('rejects negative numbers', () {
      expect(ProposalValidators.budget('-1'), 'Budget cannot be negative');
    });

    test('rejects too big numbers and bad text', () {
      for (final String bad in <String>[
        '10000000000',
        '99999999999.99',
        'abc',
        '1e5',
        '1.',
        '.5',
        '1.2.3',
        '12 34',
        '1,500.50',
        '\$100',
      ]) {
        expect(ProposalValidators.budget(bad), isNotNull, reason: bad);
      }
    });

    test('parseBudget', () {
      expect(ProposalValidators.parseBudget('1500.5'), 1500.5);
      expect(ProposalValidators.parseBudget('0'), 0.0);
      expect(ProposalValidators.parseBudget(''), isNull);
      expect(ProposalValidators.parseBudget('abc'), isNull);
      expect(ProposalValidators.parseBudget('1.999'), isNull);
    });
  });

  group('budget number', () {
    test('0 to the maximum with 2 decimals', () {
      expect(ProposalValidators.budgetValue(0), isNull);
      expect(ProposalValidators.budgetValue(12.34), isNull);
      expect(ProposalValidators.budgetValue(9999999999.99), isNull);
    });

    test('rejects bad numbers', () {
      expect(ProposalValidators.budgetValue(-0.01), isNotNull);
      expect(ProposalValidators.budgetValue(10000000000), isNotNull);
      expect(ProposalValidators.budgetValue(1.999), isNotNull);
      expect(ProposalValidators.budgetValue(double.nan), isNotNull);
      expect(ProposalValidators.budgetValue(double.infinity), isNotNull);
    });
  });

  group('link', () {
    test('optional', () {
      expect(ProposalValidators.link(null), isNull);
      expect(ProposalValidators.link('  '), isNull);
    });

    test('accepts http and https', () {
      expect(ProposalValidators.link('https://example.com/job?id=1'), isNull);
      expect(ProposalValidators.link('http://example.com'), isNull);
      expect(ProposalValidators.link('  https://example.com  '), isNull);
    });

    test('must start with a lowercase scheme', () {
      for (final String bad in <String>[
        'HTTP://example.com',
        'Https://example.com',
        'example.com',
        'ftp://example.com',
        'javascript:alert(1)',
        '//example.com',
      ]) {
        expect(ProposalValidators.link(bad), isNotNull, reason: bad);
      }
    });

    test('needs something after the scheme', () {
      expect(ProposalValidators.link('http://'), isNotNull);
      expect(ProposalValidators.link('https://'), isNotNull);
    });

    test('no spaces or control characters', () {
      expect(ProposalValidators.link('https://exa mple.com'), isNotNull);
      expect(ProposalValidators.link('https://example.com/a\nb'), isNotNull);
      expect(ProposalValidators.link('https://example.com/\u0000'), isNotNull);
    });

    test('max 2048 characters', () {
      final String prefix = 'https://a.b/';
      expect(
        ProposalValidators.link(prefix + rep(2048 - prefix.length)),
        isNull,
      );
      expect(
        ProposalValidators.link(prefix + rep(2049 - prefix.length)),
        isNotNull,
      );
    });
  });

  group('notes', () {
    test('optional', () {
      expect(ProposalValidators.notes(null), isNull);
      expect(ProposalValidators.notes(''), isNull);
    });

    test('max 4000 characters', () {
      expect(ProposalValidators.notes(rep(4000)), isNull);
      expect(ProposalValidators.notes(rep(4001)), isNotNull);
    });

    test('line breaks and tabs are allowed', () {
      expect(ProposalValidators.notes('a\nb\r\nc\td'), isNull);
    });

    test('other control characters are not allowed', () {
      expect(ProposalValidators.notes('a\u0000b'), isNotNull);
      expect(ProposalValidators.notes('a\u001Bb'), isNotNull);
      expect(ProposalValidators.notes('a\u007Fb'), isNotNull);
    });
  });

  group('search', () {
    test('empty is fine and normalizes to null', () {
      expect(ProposalValidators.searchQuery(null), isNull);
      expect(ProposalValidators.searchQuery('   '), isNull);
      expect(ProposalValidators.normalizeSearchQuery('   '), isNull);
      expect(ProposalValidators.normalizeSearchQuery(null), isNull);
    });

    test('normalize trims', () {
      expect(ProposalValidators.normalizeSearchQuery('  flutter '), 'flutter');
    });

    test('max 100 characters', () {
      expect(ProposalValidators.searchQuery(rep(100)), isNull);
      expect(ProposalValidators.searchQuery(rep(101)), isNotNull);
    });

    test('no control characters', () {
      expect(ProposalValidators.searchQuery('a\nb'), isNotNull);
      expect(ProposalValidators.searchQuery('a\u0000b'), isNotNull);
    });
  });

  group('draft', () {
    ProposalDraft good() => ProposalDraft(
      title: 'Flutter app',
      company: 'Acme',
      platform: ProposalPlatform.upwork,
      status: ProposalStatus.sent,
      budget: 100.5,
      followUpDate: CalendarDate(2026, 12, 31),
      link: 'https://example.com',
      notes: 'Note',
    );

    test('a good draft has no errors', () {
      expect(ProposalValidators.draft(good()), isEmpty);
    });

    test('the empty draft only fails on the title', () {
      final Map<ProposalField, String> errors = ProposalValidators.draft(
        const ProposalDraft.empty(),
      );

      expect(errors.keys, <ProposalField>[ProposalField.title]);
    });

    test('collects errors for several fields', () {
      final Map<ProposalField, String> errors = ProposalValidators.draft(
        ProposalDraft(
          title: 'ab',
          company: rep(121),
          platform: ProposalPlatform.other,
          status: ProposalStatus.lost,
          budget: -1,
          link: 'nope',
          notes: rep(4001),
        ),
      );

      expect(errors.keys.toSet(), <ProposalField>{
        ProposalField.title,
        ProposalField.company,
        ProposalField.budget,
        ProposalField.link,
        ProposalField.notes,
      });
    });

    test('the result cannot be changed', () {
      final Map<ProposalField, String> errors = ProposalValidators.draft(
        good(),
      );
      expect(() => errors[ProposalField.title] = 'x', throwsUnsupportedError);
    });
  });
}
