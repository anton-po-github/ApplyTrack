import 'package:apply_track/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEmail', () {
    test('trims and lowercases', () {
      expect(AuthValidators.normalizeEmail('  A@B.com '), 'a@b.com');
    });
  });

  group('email', () {
    test('empty or spaces is required', () {
      expect(AuthValidators.email(null), 'Email is required');
      expect(AuthValidators.email('   '), 'Email is required');
    });

    test('normal emails pass (spaces and case are ignored)', () {
      expect(AuthValidators.email('anton@example.com'), isNull);
      expect(AuthValidators.email(' Anton@Example.COM '), isNull);
    });

    test('bad shapes are rejected', () {
      const bad = <String>[
        'abc',
        'a@b',
        'a b@c.com',
        '@c.com',
        'a@@c.com',
        'a@c..com',
        'a@.com',
        'a@c.',
        'a,b@c.com',
        'a;b@c.com',
        'a<b@c.com',
        'a>b@c.com',
        'ä@c.com',
      ];
      for (final value in bad) {
        expect(
          AuthValidators.email(value),
          'Enter a valid email',
          reason: value,
        );
      }
    });

    test('local part: 64 passes, 65 fails', () {
      expect(AuthValidators.email('${'a' * 64}@c.com'), isNull);
      expect(AuthValidators.email('${'a' * 65}@c.com'), 'Enter a valid email');
    });

    test('total length: 255 passes, 256 fails', () {
      expect(AuthValidators.email('${'a' * 64}@${'b' * 186}.com'), isNull);
      expect(
        AuthValidators.email('${'a' * 64}@${'b' * 187}.com'),
        'Enter a valid email',
      );
    });
  });

  group('signupPassword', () {
    test('empty is required', () {
      expect(AuthValidators.signupPassword(null), 'Password is required');
      expect(AuthValidators.signupPassword(''), 'Password is required');
    });

    test('7 is too short, 8 passes', () {
      expect(
        AuthValidators.signupPassword('1234567'),
        'Use at least 8 characters',
      );
      expect(AuthValidators.signupPassword('12345678'), isNull);
    });

    test('128 passes, 129 is too long', () {
      expect(AuthValidators.signupPassword('a' * 128), isNull);
      expect(
        AuthValidators.signupPassword('a' * 129),
        'Use at most 128 characters',
      );
    });
  });

  group('signinPassword', () {
    test('empty is required', () {
      expect(AuthValidators.signinPassword(''), 'Password is required');
    });

    test('short passwords pass (old accounts), 129 is too long', () {
      expect(AuthValidators.signinPassword('a'), isNull);
      expect(
        AuthValidators.signinPassword('a' * 129),
        'Use at most 128 characters',
      );
    });
  });

  group('displayName', () {
    test('empty or spaces is required', () {
      expect(AuthValidators.displayName(null), 'Name is required');
      expect(AuthValidators.displayName('   '), 'Name is required');
    });

    test('normal name passes, outer spaces are ignored', () {
      expect(AuthValidators.displayName(' Anton '), isNull);
      expect(AuthValidators.displayName(' ${'a' * 80} '), isNull);
    });

    test('81 characters is too long', () {
      expect(AuthValidators.displayName('a' * 81), 'Name is too long');
    });

    test('control characters are rejected', () {
      expect(
        AuthValidators.displayName('An\nton'),
        'Name has invalid characters',
      );
      expect(
        AuthValidators.displayName('An\tton'),
        'Name has invalid characters',
      );
    });
  });
}
