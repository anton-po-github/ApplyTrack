import 'package:apply_track/features/proposals/domain/proposal_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a GUID in any letter case', () {
    expect(ProposalId.isValid('0190a1b2-0000-7000-8000-000000000001'), isTrue);
    expect(ProposalId.isValid('0190A1B2-0000-7000-8000-00000000ABCD'), isTrue);
  });

  test('rejects everything else', () {
    for (final bad in <String?>[
      null,
      '',
      'abc',
      '0190a1b2000070008000000000000001',
      '0190a1b2-0000-7000-8000-00000000000',
      '0190a1b2-0000-7000-8000-0000000000012',
      '0190a1b2-0000-7000-8000-00000000000g',
      ' 0190a1b2-0000-7000-8000-000000000001',
      '0190a1b2-0000-7000-8000-000000000001\n',
      '../0190a1b2-0000-7000-8000-000000000001',
    ]) {
      expect(ProposalId.isValid(bad), isFalse, reason: '$bad');
    }
  });
}
