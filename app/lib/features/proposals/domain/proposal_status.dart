/// Status numbers from 07-api-schema.md (section 3).
/// The order of the values MUST match [apiValue] (0, 1, 2, ...).
/// This gives an O(1) lookup by index. A test checks it.
enum ProposalStatus {
  draft(0, 'Draft'),
  sent(1, 'Sent'),
  viewed(2, 'Viewed'),
  interview(3, 'Interview'),
  won(4, 'Won'),
  lost(5, 'Lost');

  new(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// An unknown number throws [FormatException]. The HTTP client turns it
  /// into a `bad_response` error.
  static ProposalStatus fromApi(int value) {
    if (value < 0 || value >= values.length) {
      throw const FormatException('Unknown proposal status');
    }
    return values[value];
  }
}
