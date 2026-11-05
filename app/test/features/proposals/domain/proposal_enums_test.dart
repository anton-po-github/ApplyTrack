import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

void main() {
  group('ProposalStatus', () {
    test('apiValue is the index (needed for the O(1) lookup)', () {
      for (final ProposalStatus s in ProposalStatus.values) {
        expect(s.apiValue, s.index);
      }
    });

    test('has the numbers from 07 (0 to 5)', () {
      expect(ProposalStatus.draft.apiValue, 0);
      expect(ProposalStatus.sent.apiValue, 1);
      expect(ProposalStatus.viewed.apiValue, 2);
      expect(ProposalStatus.interview.apiValue, 3);
      expect(ProposalStatus.won.apiValue, 4);
      expect(ProposalStatus.lost.apiValue, 5);
      expect(ProposalStatus.values, hasLength(6));
    });

    test('fromApi reads every valid number', () {
      for (final ProposalStatus s in ProposalStatus.values) {
        expect(ProposalStatus.fromApi(s.apiValue), s);
      }
    });

    test('fromApi throws on an unknown number', () {
      expect(() => ProposalStatus.fromApi(-1), throwsFormatException);
      expect(() => ProposalStatus.fromApi(6), throwsFormatException);
    });
  });

  group('ProposalPlatform', () {
    test('apiValue is the index', () {
      for (final ProposalPlatform p in ProposalPlatform.values) {
        expect(p.apiValue, p.index);
      }
    });

    test('has the numbers from 07 (0 to 3)', () {
      expect(ProposalPlatform.upwork.apiValue, 0);
      expect(ProposalPlatform.linkedIn.apiValue, 1);
      expect(ProposalPlatform.email.apiValue, 2);
      expect(ProposalPlatform.other.apiValue, 3);
      expect(ProposalPlatform.values, hasLength(4));
    });

    test('fromApi reads every valid number', () {
      for (final ProposalPlatform p in ProposalPlatform.values) {
        expect(ProposalPlatform.fromApi(p.apiValue), p);
      }
    });

    test('fromApi throws on an unknown number', () {
      expect(() => ProposalPlatform.fromApi(-1), throwsFormatException);
      expect(() => ProposalPlatform.fromApi(4), throwsFormatException);
    });
  });
}
