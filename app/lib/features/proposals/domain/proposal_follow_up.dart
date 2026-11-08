import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

extension ProposalFollowUp on Proposal {
  /// True when the client was written to (Sent or Viewed) and the follow-up
  /// date is [today] or earlier. Other statuses never need a follow-up.
  bool isFollowUpDue(CalendarDate today) {
    final date = followUpDate;
    if (date == null) {
      return false;
    }
    if (status != ProposalStatus.sent && status != ProposalStatus.viewed) {
      return false;
    }
    return !today.isBefore(date);
  }
}
