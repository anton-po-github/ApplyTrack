import 'package:apply_track/core/api/json_fields.dart';
import 'package:meta/meta.dart';

@immutable
final class UserProfile {
  const new({required this.id, required this.email, required this.displayName});

  factory fromJson(Map<String, Object?> json) => UserProfile(
    id: json.requireString('id'),
    email: json.requireString('email'),
    displayName: json.requireString('displayName'),
  );

  final String id;
  final String email;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);
}
