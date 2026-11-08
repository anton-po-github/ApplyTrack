import 'package:apply_track/features/proposals/domain/proposal_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProposalLink.tryParse', () {
    test('a normal https or http link is allowed', () {
      expect(
        ProposalLink.tryParse('https://acme.io/job?id=1'),
        Uri.parse('https://acme.io/job?id=1'),
      );
      expect(ProposalLink.tryParse('http://acme.io'), isNotNull);
    });

    test('spaces around the link are ignored', () {
      expect(ProposalLink.tryParse('  https://acme.io  '), isNotNull);
    });

    test('null, empty and blank give null', () {
      expect(ProposalLink.tryParse(null), isNull);
      expect(ProposalLink.tryParse(''), isNull);
      expect(ProposalLink.tryParse('   '), isNull);
    });

    test('other schemes give null', () {
      for (final text in <String>[
        'javascript:alert(1)',
        'file:///etc/passwd',
        'mailto:a@b.com',
        'ftp://acme.io',
        'data:text/html,hi',
      ]) {
        expect(ProposalLink.tryParse(text), isNull, reason: text);
      }
    });

    test('upper case scheme gives null (same rule as the form)', () {
      expect(ProposalLink.tryParse('HTTP://acme.io'), isNull);
    });

    test('no host, spaces inside or too long give null', () {
      expect(ProposalLink.tryParse('https://'), isNull);
      expect(ProposalLink.tryParse('https:///path'), isNull);
      expect(ProposalLink.tryParse('https://acme.io/a b'), isNull);
      expect(ProposalLink.tryParse('https://acme.io/${'a' * 2048}'), isNull);
    });
  });
}
