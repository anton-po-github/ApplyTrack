import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/auth_validators.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/ui/auth_form_errors.dart';
import 'package:apply_track/features/auth/ui/auth_widgets.dart';
import 'package:apply_track/router/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

    // On success the router guard moves us to the main screen.
    if (outcome is! AuthFailure || outcome.kind == AuthFailureKind.busy) return;

    setState(() {
      _errors = AuthFormErrors.fromFailure(outcome, knownFields: _knownFields);
    });
    form.validate();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(authBusyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: MaxContentWidth(
        maxWidth: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                AuthSubmitButton(
                  label: 'Sign in',
                  busy: busy,
                  onPressed: _submit,
                ),
                // Enabled in Step 7.
                const OutlinedButton(
                  onPressed: null,
                  child: Text('Continue with Google'),
                ),
                TextButton(
                  onPressed: busy ? null : () => context.go(AppRoutes.signup),
                  child: const Text('No account? Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
