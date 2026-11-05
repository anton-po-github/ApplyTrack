import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/core/api/json_fields.dart';

void main() {
  group('requireNum', () {
    test('reads int and double', () {
      final Map<String, Object?> json = <String, Object?>{'a': 5, 'b': 5.5};
      expect(json.requireNum('a'), 5);
      expect(json.requireNum('b'), 5.5);
    });

    test('throws on a string, null or missing key', () {
      final Map<String, Object?> json = <String, Object?>{'a': '5', 'b': null};
      expect(() => json.requireNum('a'), throwsFormatException);
      expect(() => json.requireNum('b'), throwsFormatException);
      expect(() => json.requireNum('c'), throwsFormatException);
    });
  });

  group('optional readers', () {
    final Map<String, Object?> json = <String, Object?>{
      's': 'text',
      'i': 3,
      'n': 2.5,
      'nil': null,
      'bad': <Object?>[],
    };

    test('return the value when it has the right type', () {
      expect(json.optionalString('s'), 'text');
      expect(json.optionalInt('i'), 3);
      expect(json.optionalNum('n'), 2.5);
      expect(json.optionalNum('i'), 3);
    });

    test('return null for null and for a missing key', () {
      expect(json.optionalString('nil'), isNull);
      expect(json.optionalInt('missing'), isNull);
      expect(json.optionalNum('nil'), isNull);
    });

    test('throw on a wrong type', () {
      expect(() => json.optionalString('bad'), throwsFormatException);
      expect(() => json.optionalInt('n'), throwsFormatException);
      expect(() => json.optionalNum('s'), throwsFormatException);
    });

    test('the error message never has the value', () {
      final Map<String, Object?> secret = <String, Object?>{'t': 12345};
      expect(
        () => secret.optionalString('t'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            isNot(contains('12345')),
          ),
        ),
      );
    });
  });

  group('requireObjectList', () {
    test('reads a list of objects and the list cannot be changed', () {
      final Map<String, Object?> json = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'id': 'a'},
          <String, Object?>{'id': 'b'},
        ],
      };

      final List<Map<String, Object?>> items = json.requireObjectList('items');

      expect(items.map((Map<String, Object?> m) => m['id']), <Object?>[
        'a',
        'b',
      ]);
      expect(() => items.add(<String, Object?>{}), throwsUnsupportedError);
    });

    test('an empty list is fine', () {
      final Map<String, Object?> json = <String, Object?>{'items': <Object?>[]};
      expect(json.requireObjectList('items'), isEmpty);
    });

    test('throws when it is not a list or has a non-object item', () {
      expect(
        () => <String, Object?>{'items': 'x'}.requireObjectList('items'),
        throwsFormatException,
      );
      expect(
        () => <String, Object?>{'items': null}.requireObjectList('items'),
        throwsFormatException,
      );
      expect(
        () => <String, Object?>{
          'items': <Object?>[1],
        }.requireObjectList('items'),
        throwsFormatException,
      );
    });
  });
}
