import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/auth/data/session.dart';

void main() {
  final DateTime now = DateTime.fromMillisecondsSinceEpoch(
    1767225600 * 1000,
    isUtc: true,
  );

  test('not expired before the expiry second', () {
    final Session s = Session(token: 't', expiresAtUnixSeconds: 1767225601);
    expect(s.isExpired(now), isFalse);
  });

  test('expired at the expiry second', () {
    final Session s = Session(token: 't', expiresAtUnixSeconds: 1767225600);
    expect(s.isExpired(now), isTrue);
  });

  test('expired after the expiry second', () {
    final Session s = Session(token: 't', expiresAtUnixSeconds: 1767225000);
    expect(s.isExpired(now), isTrue);
  });

  test('equal sessions are equal', () {
    const Session a = Session(token: 't', expiresAtUnixSeconds: 5);
    const Session b = Session(token: 't', expiresAtUnixSeconds: 5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('toString hides the token', () {
    const Session s = Session(token: 'secret-token', expiresAtUnixSeconds: 5);
    expect(s.toString(), isNot(contains('secret-token')));
  });
}
