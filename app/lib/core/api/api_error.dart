/// Codes from 07-api-schema.md (section 7) plus client-only codes.
abstract final class ApiErrorCodes {
  static const String validation = 'validation';
  static const String badRequest = 'bad_request';
  static const String googleEmailUnsupported = 'google_email_unsupported';
  static const String unauthorized = 'unauthorized';
  static const String invalidCredentials = 'invalid_credentials';
  static const String invalidGoogleToken = 'invalid_google_token';
  static const String notFound = 'not_found';
  static const String emailTaken = 'email_taken';
  static const String proposalLimit = 'proposal_limit';
  static const String rateLimited = 'rate_limited';
  static const String serverError = 'server_error';

  // Client only: the server never sends these.
  static const String network = 'network_error';
  static const String badResponse = 'bad_response';
  static const String unknown = 'unknown_error';
}

final class ApiError {
  const new({
    required this.code,
    required this.message,
    this.fields,
    this.retryAfterSeconds,
  });

  const new network()
    : this(
        code: ApiErrorCodes.network,
        message: 'No connection. Check your internet and try again.',
      );

  const new unauthorized()
    : this(code: ApiErrorCodes.unauthorized, message: 'Please sign in again.');

  const new badResponse()
    : this(
        code: ApiErrorCodes.badResponse,
        message: 'The server sent an unexpected answer.',
      );

  /// Never throws. A broken body becomes code `unknown_error`.
  factory fromJson(Map<String, Object?> json, {int? retryAfterSeconds}) {
    final code = json['code'];
    final message = json['message'];
    return ApiError(
      code: code is String && code.isNotEmpty ? code : ApiErrorCodes.unknown,
      message: message is String && message.isNotEmpty
          ? message
          : 'Something went wrong.',
      fields: _readFields(json['fields']),
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  final String code;
  final String message;

  /// Form errors: field name -> message. Null when there are none.
  final Map<String, String>? fields;

  /// From the `Retry-After` header (429 only).
  final int? retryAfterSeconds;

  static Map<String, String>? _readFields(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String) result[entry.key] = value;
    }
    return result.isEmpty ? null : Map<String, String>.unmodifiable(result);
  }
}
