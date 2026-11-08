import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/domain/auth_validators.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/ui/auth_form_errors.dart';
import 'package:apply_track/features/auth/ui/auth_layout.dart';
import 'package:apply_track/features/auth/ui/auth_widgets.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static const String _description =
      'Create an account to start tracking your proposals. Save each one, '
      'set follow-up dates, and see how many you win.';
  static const Set<String> _knownFields = <String>{
    'displayName',
    'email',
    'password',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  AuthFormErrors _errors = AuthFormErrors.none;

  @override
  void dispose() {
    _name.dispose();
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
    final form = _formKey.currentState;
    if (form == null) return;

    setState(() => _errors = AuthFormErrors.none);
    if (!form.validate()) return;

    final outcome = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
    if (!mounted) return;

    if (outcome is! AuthFailure || outcome.kind == AuthFailureKind.busy) return;

    setState(() {
      _errors = AuthFormErrors.fromFailure(outcome, knownFields: _knownFields);
    });
    form.validate();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authBusyProvider);

    return AuthLayout(
      description: _description,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: <Widget>[
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearError('displayName'),
              validator: (value) =>
                  _errors.fields['displayName'] ??
                  AuthValidators.displayName(value),
            ),
            EmailField(
              controller: _email,
              onChanged: (_) => _clearError('email'),
              validator: (value) =>
                  _errors.fields['email'] ?? AuthValidators.email(value),
            ),
            PasswordField(
              controller: _password,
              isNewPassword: true,
              helperText: '8 to 128 characters',
              onChanged: (_) => _clearError('password'),
              onSubmitted: (_) => _submit(),
              validator: (value) =>
                  _errors.fields['password'] ??
                  AuthValidators.signupPassword(value),
            ),
            if (_errors.message case final String message)
              AuthErrorBanner(message: message),
            AuthSubmitButton(
              label: 'Create account',
              busy: busy,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.login),
              child: const Text('Have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
