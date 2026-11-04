import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:apply_track/features/auth/data/session.dart';

abstract interface class TokenStorage {
  /// Returns null when there is no session or the stored data is broken.
  /// Broken data is cleared.
  Future<Session?> read();

  Future<void> write(Session session);

  Future<void> clear();
}

/// For tests (and fakes). Nothing is saved to disk.
final class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._session]);

  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// Android Keystore / iOS Keychain. On web it uses `localStorage`.
/// The whole session is ONE key, so a save is all or nothing.
final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String storageKey = 'applytrack.session';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: storageKey);
    } on Exception {
      await _safeClear();
      return null;
    }
    if (raw == null) return null;

    final Session? session = _decode(raw);
    if (session == null) await _safeClear();
    return session;
  }

  /// Can throw if the device storage fails. The caller decides what to do.
  @override
  Future<void> write(Session session) => _storage.write(
    key: storageKey,
    value: jsonEncode(<String, Object>{
      'token': session.token,
      'exp': session.expiresAtUnixSeconds,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: storageKey);

  Future<void> _safeClear() async {
    try {
      await _storage.delete(key: storageKey);
    } on Exception {
      // Nothing more we can do. The next read tries again.
    }
  }

  static Session? _decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    final Object? token = json['token'];
    final Object? exp = json['exp'];
    if (token is! String || token.isEmpty) return null;
    if (exp is! int || exp <= 0) return null;
    return Session(token: token, expiresAtUnixSeconds: exp);
  }
}
