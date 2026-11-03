abstract final class SignupValidators {
  static const int nameMin = 2;
  static const int nameMax = 50;
  static const int emailMax = 254;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Name is required';
    if (text.length < nameMin) return 'Name is too short';
    if (text.length > nameMax) return 'Name is too long';
    return null;
  }

  static String? email(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Email is required';
    if (text.length > emailMax || !_email.hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }
}
