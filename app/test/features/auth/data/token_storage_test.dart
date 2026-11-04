import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';

/// A simple in-memory fake of the plugin. It can fail on demand.
final class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = <String, String>{};
  bool failReads = false;
  int deletes = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failReads) throw Exception('storage failed');
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletes++;
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const Session session = Session(
    token: 'abc',
    expiresAtUnixSeconds: 1767225600,
  );

  group('InMemoryTokenStorage', () {
    test('starts empty', () async {
      expect(await InMemoryTokenStorage().read(), isNull);
    });

    test('write, read, clear', () async {
      final InMemoryTokenStorage storage = InMemoryTokenStorage();
      await storage.write(session);
      expect(await storage.read(), session);
      await storage.clear();
      expect(await storage.read(), isNull);
    });

    test('can start with a session', () async {
      expect(await InMemoryTokenStorage(session).read(), session);
    });
  });

  group('SecureTokenStorage', () {
    late _FakeSecureStorage fake;
    late SecureTokenStorage storage;

    setUp(() {
      fake = _FakeSecureStorage();
      storage = SecureTokenStorage(storage: fake);
    });

    test('empty storage means no session', () async {
      expect(await storage.read(), isNull);
      expect(fake.deletes, 0);
    });

    test('write then read returns the same session', () async {
      await storage.write(session);
      expect(await storage.read(), session);
    });

    test('the session is saved under ONE key', () async {
      await storage.write(session);
      expect(fake.data.keys, <String>[SecureTokenStorage.storageKey]);
    });

    test('clear removes the session', () async {
      await storage.write(session);
      await storage.clear();
      expect(await storage.read(), isNull);
    });

    for (final MapEntry<String, String> bad in <String, String>{
      'not json': 'not json',
      'json array': '[1,2]',
      'missing exp': '{"token":"abc"}',
      'missing token': '{"exp":1767225600}',
      'empty token': '{"token":"","exp":1767225600}',
      'exp is a string': '{"token":"abc","exp":"1767225600"}',
      'exp is zero': '{"token":"abc","exp":0}',
      'exp is negative': '{"token":"abc","exp":-5}',
      'token is a number': '{"token":123,"exp":1767225600}',
    }.entries) {
      test('broken data (${bad.key}) is no session and is cleared', () async {
        fake.data[SecureTokenStorage.storageKey] = bad.value;

        expect(await storage.read(), isNull);
        expect(fake.data, isEmpty);
      });
    }

    test('a failing read is no session and tries to clear', () async {
      fake.data[SecureTokenStorage.storageKey] = '{"token":"a","exp":5}';
      fake.failReads = true;

      expect(await storage.read(), isNull);
      expect(fake.deletes, 1);
    });
  });
}
