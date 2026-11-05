/// Proposal ids are GUID strings (UUID v7). We check the shape before an id
/// goes into a URL path, so a bad id can never change the path.
abstract final class ProposalId {
  static final RegExp _guid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValid(String? value) => value != null && _guid.hasMatch(value);
}
