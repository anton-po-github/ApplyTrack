import 'package:apply_track/features/proposals/domain/proposal_validators.dart';

/// Decides if a stored link may be opened. We do not trust the server data
/// here: another client could have saved any text.
abstract final class ProposalLink {
  /// The link as a [Uri], or null when it must not be opened.
  /// Same rules as the form validator, and the result has a host.
  static Uri? tryParse(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty || ProposalValidators.link(text) != null) {
      return null;
    }
    final Uri? uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return uri;
  }
}
