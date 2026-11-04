import 'package:apply_track/core/api/json_fields.dart';

final class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    id: json.requireString('id'),
    email: json.requireString('email'),
    displayName: json.requireString('displayName'),
  );

  final String id;
  final String email;
  final String displayName;
}
