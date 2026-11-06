import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_status_flow.dart';

void main() {
  group('ProposalStatusFlow.next', () {
    test('Draft -> Sent -> Viewed -> Interview', () {
      expect(ProposalStatusFlow.next(ProposalStatus.draft), <ProposalStatus>[
        ProposalStatus.sent,
      ]);
      expect(ProposalStatusFlow.next(ProposalStatus.sent), <ProposalStatus>[
        ProposalStatus.viewed,
      ]);
      expect(ProposalStatusFlow.next(ProposalStatus.viewed), <ProposalStatus>[
        ProposalStatus.interview,
      ]);
    });

    test('Interview goes to Won or Lost', () {
      expect(
        ProposalStatusFlow.next(ProposalStatus.interview),
        <ProposalStatus>[ProposalStatus.won, ProposalStatus.lost],
      );
    });

    test('Won and Lost are the end', () {
      expect(ProposalStatusFlow.next(ProposalStatus.won), isEmpty);
      expect(ProposalStatusFlow.next(ProposalStatus.lost), isEmpty);
    });

    test('every status has an answer and never points to itself', () {
      for (final ProposalStatus status in ProposalStatus.values) {
        expect(ProposalStatusFlow.next(status), isNot(contains(status)));
      }
    });

    test('the list cannot be changed by the caller', () {
      expect(
        () =>
            ProposalStatusFlow.next(ProposalStatus.draft)
                .add(ProposalStatus.won),
        throwsUnsupportedError,
      );
    });
  });
}
