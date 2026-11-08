import 'package:apply_track/core/api/json_fields.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';

/// One page of the list (`ProposalListResponse` in 07).
final class ProposalPage {
  const new({required this.items, this.nextCursor});

  factory fromJson(Map<String, Object?> json) => ProposalPage(
    items: List<Proposal>.unmodifiable(
      json.requireObjectList('items').map(Proposal.fromJson),
    ),
    nextCursor: json.optionalString('nextCursor'),
  );

  /// Newest first (the server sorts by id, descending).
  final List<Proposal> items;

  /// Null means this is the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
