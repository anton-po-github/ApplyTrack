import 'package:apply_track/features/auth/data/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(
    1767225600 * 1000,
    isUtc: true,
  );

  test('not expired before the expiry second', () {
    const s = Session(token: 't', expiresAtUnixSeconds: 1767225601);
    expect(s.isExpired(now), isFalse);
  });

  test('expired at the expiry second', () {
    const s = Session(token: 't', expiresAtUnixSeconds: 1767225600);
    expect(s.isExpired(now), isTrue);
  });

  test('expired after the expiry second', () {
    const s = Session(token: 't', expiresAtUnixSeconds: 1767225000);
    expect(s.isExpired(now), isTrue);
  });

  test('equal sessions are equal', () {
    const a = Session(token: 't', expiresAtUnixSeconds: 5);
    const b = Session(token: 't', expiresAtUnixSeconds: 5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('toString hides the token', () {
    const s = Session(token: 'secret-token', expiresAtUnixSeconds: 5);
    expect(s.toString(), isNot(contains('secret-token')));
  });
}
