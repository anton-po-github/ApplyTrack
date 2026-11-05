import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/ui/auth_form_errors.dart';

const Set<String> _known = <String>{'email', 'password'};

void main() {
  test('known fields are shown under the inputs, no general message', () {
    final AuthFormErrors e = AuthFormErrors.fromFailure(
      const AuthFailure(
        kind: AuthFailureKind.validation,
        message: 'Please fix the fields.',
        fields: <String, String>{'email': 'Bad email.'},
      ),
      knownFields: _known,
    );

    expect(e.fields, <String, String>{'email': 'Bad email.'});
    expect(e.message, isNull);
  });

  test('unknown field names are dropped, the message is shown', () {
    final AuthFormErrors e = AuthFormErrors.fromFailure(
      const AuthFailure(
        kind: AuthFailureKind.validation,
        message: 'Please fix the fields.',
        fields: <String, String>{'surprise': 'x'},
      ),
      knownFields: _known,
    );

    expect(e.fields, isEmpty);
    expect(e.message, 'Please fix the fields.');
  });

  test('no fields: one general message', () {
    final AuthFormErrors e = AuthFormErrors.fromFailure(
      const AuthFailure(
        kind: AuthFailureKind.invalidCredentials,
        message: 'Wrong email or password.',
      ),
      knownFields: _known,
    );

    expect(e.fields, isEmpty);
    expect(e.message, 'Wrong email or password.');
  });

  test('without removes only one field', () {
    const AuthFormErrors e = AuthFormErrors(
      fields: <String, String>{'email': 'a', 'password': 'b'},
    );

    expect(e.without('email').fields, <String, String>{'password': 'b'});
    expect(identical(e.without('nope'), e), isTrue);
  });
}
