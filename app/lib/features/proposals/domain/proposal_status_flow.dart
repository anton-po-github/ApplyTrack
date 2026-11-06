import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// The quick "next stage" actions on the detail screen:
/// Draft -> Sent -> Viewed -> Interview -> Won or Lost.
///
/// This is only a shortcut. The server accepts any status, and the edit form
/// can set any status. Every lookup is O(1) and returns a shared constant
/// list.
abstract final class ProposalStatusFlow {
  static const List<ProposalStatus> _none = <ProposalStatus>[];
  static const List<ProposalStatus> _toSent = <ProposalStatus>[
    ProposalStatus.sent,
  ];
  static const List<ProposalStatus> _toViewed = <ProposalStatus>[
    ProposalStatus.viewed,
  ];
  static const List<ProposalStatus> _toInterview = <ProposalStatus>[
    ProposalStatus.interview,
  ];
  static const List<ProposalStatus> _toClosed = <ProposalStatus>[
    ProposalStatus.won,
    ProposalStatus.lost,
  ];

  /// The statuses the user can pick next. Empty for Won and Lost.
  static List<ProposalStatus> next(ProposalStatus status) => switch (status) {
    ProposalStatus.draft => _toSent,
    ProposalStatus.sent => _toViewed,
    ProposalStatus.viewed => _toInterview,
    ProposalStatus.interview => _toClosed,
    ProposalStatus.won || ProposalStatus.lost => _none,
  };
}
