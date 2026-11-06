import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/auth_validators.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/ui/google_button.dart';
import 'package:apply_track/features/auth/ui/auth_form_errors.dart';
import 'package:apply_track/features/auth/ui/auth_layout.dart';
import 'package:apply_track/features/auth/ui/auth_widgets.dart';
import 'package:apply_track/router/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _description =
      'Track every job proposal in one place. Move each one from draft to '
      'won or lost, and never miss a follow-up. See your stats to learn '
      'what works.';
  static const Set<String> _knownFields = <String>{'email', 'password'};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  AuthFormErrors _errors = AuthFormErrors.none;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_errors.fields.containsKey(field)) {
      setState(() => _errors = _errors.without(field));
    }
  }

  /// Shows a failure. Busy and cancelled show nothing.
  void _showFailure(AuthOutcome outcome) {
    if (outcome is! AuthFailure) return; // Success: the router moves us.
    if (outcome.kind == AuthFailureKind.busy ||
        outcome.kind == AuthFailureKind.cancelled) {
      return;
    }
    setState(() {
      _errors = AuthFormErrors.fromFailure(outcome, knownFields: _knownFields);
    });
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null) return;

    // Old server errors must not block the new check.
    setState(() => _errors = AuthFormErrors.none);
    if (!form.validate()) return;

    final AuthOutcome outcome = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    _showFailure(outcome);
  }

  void _clearErrors() => setState(() => _errors = AuthFormErrors.none);

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(authBusyProvider);

    return AuthLayout(
      description: _description,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: <Widget>[
            EmailField(
              controller: _email,
              onChanged: (String _) => _clearError('email'),
              validator: (String? value) =>
                  _errors.fields['email'] ?? AuthValidators.email(value),
            ),
            PasswordField(
              controller: _password,
              isNewPassword: false,
              onChanged: (String _) => _clearError('password'),
              onSubmitted: (String _) => _submit(),
              validator: (String? value) =>
                  _errors.fields['password'] ??
                  AuthValidators.signinPassword(value),
            ),
            if (_errors.message case final String message)
              AuthErrorBanner(message: message),
            AuthSubmitButton(label: 'Sign in', busy: busy, onPressed: _submit),
            GoogleSignInButton(
              onStarted: _clearErrors,
              onOutcome: _showFailure,
            ),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.signup),
              child: const Text('No account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
