import 'package:apply_track/features/auth/domain/auth_outcome.dart';

/// What a form shows after the server said no.
/// Field errors go under the inputs. Everything else is one message.
final class AuthFormErrors {
  const new({this.fields = const <String, String>{}, this.message});

  factory fromFailure(AuthFailure failure, {required Set<String> knownFields}) {
    final shown = <String, String>{
      for (final MapEntry<String, String> entry
          in (failure.fields ?? const <String, String>{}).entries)
        if (knownFields.contains(entry.key)) entry.key: entry.value,
    };
    return AuthFormErrors(
      fields: shown,
      message: shown.isEmpty ? failure.message : null,
    );
  }

  static const AuthFormErrors none = AuthFormErrors();

  /// Field name -> message.
  final Map<String, String> fields;

  /// One general message (wrong password, 429, no network...).
  final String? message;

  /// The user is typing in [field], so its server error is old now.
  AuthFormErrors without(String field) {
    if (!fields.containsKey(field)) return this;
    return AuthFormErrors(
      fields: Map<String, String>.of(fields)..remove(field),
      message: message,
    );
  }
}
