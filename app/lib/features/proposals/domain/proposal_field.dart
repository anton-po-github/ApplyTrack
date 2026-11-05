/// The form inputs of a proposal. [apiKey] is the field name in the
/// server `fields` map (07-api-schema.md, `ErrorResponse`).
enum ProposalField {
  title('title'),
  company('company'),
  platform('platform'),
  status('status'),
  budget('budget'),
  followUpDate('followUpDate'),
  link('link'),
  notes('notes');

  const ProposalField(this.apiKey);

  final String apiKey;

  static final Map<String, ProposalField> _byKey = <String, ProposalField>{
    for (final ProposalField field in values) field.apiKey: field,
  };

  /// O(1). Returns null for a key we do not know.
  static ProposalField? fromApiKey(String key) => _byKey[key];
}

/// The server `fields` map, sorted into "we know this input" and
/// "we do not know it" (the UI shows these in a banner).
final class ServerFieldErrors {
  const ServerFieldErrors({required this.byField, required this.unmapped});

  factory ServerFieldErrors.from(Map<String, String>? fields) {
    if (fields == null || fields.isEmpty) return empty;
    final Map<ProposalField, String> byField = <ProposalField, String>{};
    final List<String> unmapped = <String>[];
    for (final MapEntry<String, String> entry in fields.entries) {
      final ProposalField? field = ProposalField.fromApiKey(entry.key);
      if (field == null) {
        unmapped.add(entry.value);
      } else {
        byField[field] = entry.value;
      }
    }
    return ServerFieldErrors(
      byField: Map<ProposalField, String>.unmodifiable(byField),
      unmapped: List<String>.unmodifiable(unmapped),
    );
  }

  static const ServerFieldErrors empty = ServerFieldErrors(
    byField: <ProposalField, String>{},
    unmapped: <String>[],
  );

  final Map<ProposalField, String> byField;

  /// Messages for keys that are not one of our inputs.
  final List<String> unmapped;

  bool get isEmpty => byField.isEmpty && unmapped.isEmpty;
}
