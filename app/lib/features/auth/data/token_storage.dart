import 'dart:convert';

import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/domain/user_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  /// Returns null when there is no session or the stored data is broken.
  /// Broken data is cleared.
  Future<Session?> read();

  Future<void> write(Session session);

  Future<void> clear();
}

/// For tests (and fakes). Nothing is saved to disk.
final class InMemoryTokenStorage implements TokenStorage {
  new([this._session]);

  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// Android Keystore / iOS Keychain. On web it uses `localStorage`.
/// The whole session is ONE key, so a save is all or nothing. The user is part
/// of the same key, so a token never gets the user of another account.
final class SecureTokenStorage implements TokenStorage {
  new({FlutterSecureStorage? storage})
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

    final session = _decode(raw);
    if (session == null) await _safeClear();
    return session;
  }

  /// Can throw if the device storage fails. The caller decides what to do.
  @override
  Future<void> write(Session session) {
    final user = session.user;
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, Object>{
        'token': session.token,
        'exp': session.expiresAtUnixSeconds,
        if (user != null)
          'user': <String, String>{
            'id': user.id,
            'email': user.email,
            'displayName': user.displayName,
          },
      }),
    );
  }

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
    final token = json['token'];
    final exp = json['exp'];
    if (token is! String || token.isEmpty) return null;
    if (exp is! int || exp <= 0) return null;
    return Session(
      token: token,
      expiresAtUnixSeconds: exp,
      user: _decodeUser(json['user']),
    );
  }

  /// A missing or broken user is null. It must never destroy a good token.
  static UserProfile? _decodeUser(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final UserProfile user;
    try {
      user = UserProfile.fromJson(raw);
    } on FormatException {
      return null;
    }
    if (user.id.isEmpty || user.email.isEmpty) {
      return null;
    }
    return user;
  }
}
