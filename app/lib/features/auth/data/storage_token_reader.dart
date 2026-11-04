import 'package:apply_track/core/api/token_reader.dart';
import 'package:apply_track/features/auth/data/session.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';

/// Connects the HTTP layer (TokenReader) to the storage (Step 3).
/// An expired token is never sent: it returns null.
final class StorageTokenReader implements TokenReader {
  const StorageTokenReader({required this._storage, required this._now});

  final TokenStorage _storage;
  final DateTime Function() _now;

  @override
  Future<String?> readToken() async {
    final Session? session = await _storage.read();
    if (session == null || session.isExpired(_now())) return null;
    return session.token;
  }
}
