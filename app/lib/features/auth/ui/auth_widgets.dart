import 'package:material_ui/material_ui.dart';

// Autofill hint values are plain strings in Flutter ('email', 'password',
// 'newPassword'). They let password managers fill the fields.

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const <String>['email'],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
    required this.isNewPassword,
    this.helperText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;

  /// Sign up uses `newPassword`, sign in uses `password` (autofill hint).
  final bool isNewPassword;
  final String? helperText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: <String>[
        widget.isNewPassword ? 'newPassword' : 'password',
      ],
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: 'Password',
        helperText: widget.helperText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// The button is disabled while busy, so a double tap does nothing.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
