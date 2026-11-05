import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/proposal_field.dart';

void main() {
  group('ProposalField', () {
    test('apiKey values are the field names from 07', () {
      expect(
        ProposalField.values.map((ProposalField f) => f.apiKey).toList(),
        <String>[
          'title',
          'company',
          'platform',
          'status',
          'budget',
          'followUpDate',
          'link',
          'notes',
        ],
      );
    });

    test('fromApiKey finds every field', () {
      for (final ProposalField f in ProposalField.values) {
        expect(ProposalField.fromApiKey(f.apiKey), f);
      }
    });

    test('fromApiKey gives null for an unknown key', () {
      expect(ProposalField.fromApiKey('Title'), isNull);
      expect(ProposalField.fromApiKey('userId'), isNull);
      expect(ProposalField.fromApiKey(''), isNull);
    });
  });

  group('ServerFieldErrors.from', () {
    test('null and empty maps give the empty result', () {
      expect(ServerFieldErrors.from(null).isEmpty, isTrue);
      expect(ServerFieldErrors.from(<String, String>{}).isEmpty, isTrue);
    });

    test('maps known keys to fields', () {
      final ServerFieldErrors errors = ServerFieldErrors.from(<String, String>{
        'title': 'Title is required.',
        'followUpDate': 'Bad date.',
      });

      expect(errors.byField, <ProposalField, String>{
        ProposalField.title: 'Title is required.',
        ProposalField.followUpDate: 'Bad date.',
      });
      expect(errors.unmapped, isEmpty);
      expect(errors.isEmpty, isFalse);
    });

    test('keeps the messages of unknown keys', () {
      final ServerFieldErrors errors = ServerFieldErrors.from(<String, String>{
        'title': 'Bad.',
        'other': 'Something else.',
      });

      expect(errors.byField.keys, <ProposalField>[ProposalField.title]);
      expect(errors.unmapped, <String>['Something else.']);
    });

    test('the result cannot be changed', () {
      final ServerFieldErrors errors = ServerFieldErrors.from(<String, String>{
        'title': 'Bad.',
        'x': 'y',
      });

      expect(
        () => errors.byField[ProposalField.notes] = 'x',
        throwsUnsupportedError,
      );
      expect(() => errors.unmapped.add('x'), throwsUnsupportedError);
    });
  });
}
