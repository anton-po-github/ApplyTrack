import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/storage_token_reader.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

  StorageTokenReader readerFor(Session? session) => StorageTokenReader(
    storage: InMemoryTokenStorage(session),
    now: () => now,
  );

  test('returns the token of a valid session', () async {
    final reader = readerFor(
      Session(token: 'tok', expiresAtUnixSeconds: nowSeconds + 60),
    );
    expect(await reader.readToken(), 'tok');
  });

  test('returns null when there is no session', () async {
    expect(await readerFor(null).readToken(), isNull);
  });

  test('returns null for an expired session', () async {
    final reader = readerFor(
      Session(token: 'tok', expiresAtUnixSeconds: nowSeconds),
    );
    expect(await reader.readToken(), isNull);
  });
}
