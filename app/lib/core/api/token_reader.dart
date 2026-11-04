/// The HTTP layer only needs to READ the token.
/// It does not know where the token is stored (see Step 3).
abstract interface class TokenReader {
  /// Returns null when there is no session.
  Future<String?> readToken();
}
