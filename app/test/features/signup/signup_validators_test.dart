import 'package:flutter_test/flutter_test.dart';
import 'package:phase2_widgets/features/signup/signup_validators.dart';

void main() {
  group('name', () {
    test('empty or spaces is required', () {
      expect(SignupValidators.name(null), 'Name is required');
      expect(SignupValidators.name('   '), 'Name is required');
    });

    test('one letter is too short', () {
      expect(SignupValidators.name('A'), 'Name is too short');
    });

    test('51 letters is too long', () {
      expect(SignupValidators.name('A' * 51), 'Name is too long');
    });

    test('normal name passes, spaces are ignored', () {
      expect(SignupValidators.name(' Anton '), isNull);
    });
  });

  group('email', () {
    test('empty is required', () {
      expect(SignupValidators.email(''), 'Email is required');
    });

    test('bad shapes are rejected', () {
      for (final String bad in <String>['abc', 'a@b', 'a b@c.com', '@c.com']) {
        expect(SignupValidators.email(bad), 'Enter a valid email', reason: bad);
      }
    });

    test('normal email passes', () {
      expect(SignupValidators.email('anton@example.com'), isNull);
    });
  });
}
