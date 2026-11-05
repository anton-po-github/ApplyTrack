/// Platform numbers from 07-api-schema.md (section 3).
/// The order of the values MUST match [apiValue] (0, 1, 2, ...).
enum ProposalPlatform {
  upwork(0, 'Upwork'),
  linkedIn(1, 'LinkedIn'),
  email(2, 'Email'),
  other(3, 'Other');

  const ProposalPlatform(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// An unknown number throws [FormatException].
  static ProposalPlatform fromApi(int value) {
    if (value < 0 || value >= values.length) {
      throw const FormatException('Unknown proposal platform');
    }
    return values[value];
  }
}
