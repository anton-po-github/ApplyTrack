import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/auth/data/google_id_token_provider.dart';
import 'package:apply_track/features/auth/domain/auth_outcome.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/auth/ui/google_button_stub.dart'
    if (dart.library.js_interop) 'package:apply_track/features/auth/ui/google_button_web.dart';

/// "Continue with Google". One widget, two flows:
/// - mobile: our own button, `signInWithGoogle()`;
/// - web: the button drawn by Google. The token arrives on a stream.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onStarted,
    required this.onOutcome,
  });

  /// Tests find Google's button area with this key.
  static const Key renderedButtonKey = ValueKey<String>(
    'google-rendered-button',
  );

  /// A Google sign-in attempt begins (clear old errors).
  final VoidCallback onStarted;

  /// The attempt ended. Success moves the router. Failures need a message
  /// (the parent ignores `busy` and `cancelled`).
  final ValueChanged<AuthOutcome> onOutcome;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  StreamSubscription<GoogleTokenResult>? _subscription;

  /// Web only. `null` = starting, `false` = the plugin could not start.
  bool? _webReady;

  @override
  void initState() {
    super.initState();
    final GoogleIdTokenProvider google = ref.read(googleSignInProvider);
    final bool configured = ref.read(appConfigProvider).hasGoogleClientId;

    if (configured && google.usesRenderedButton) {
      // Listen first, so no token is missed.
      _subscription = google.tokenEvents.listen(_onToken);
      unawaited(
        google.prepare().then((bool ok) {
          if (mounted) setState(() => _webReady = ok);
        }),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// Web: the user used Google's button.
  Future<void> _onToken(GoogleTokenResult token) async {
    widget.onStarted();
    final AuthOutcome outcome = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogleResult(token);
    if (!mounted) return;
    widget.onOutcome(outcome);
  }

  /// Mobile: the user tapped our button.
  Future<void> _onPressed() async {
    widget.onStarted();
    final AuthOutcome outcome = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    widget.onOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(authBusyProvider);
    final bool configured = ref.watch(appConfigProvider).hasGoogleClientId;
    final bool rendered = ref.watch(googleSignInProvider).usesRenderedButton;

    if (configured && rendered) {
      return switch (_webReady) {
        null => const SizedBox(height: 44), // Starting.
        true => Center(
          child: KeyedSubtree(
            key: GoogleSignInButton.renderedButtonKey,
            child: buildGoogleRenderedButton(),
          ),
        ),
        false => const _DisabledGoogleButton(),
      };
    }

    return OutlinedButton(
      onPressed: busy || !configured ? null : _onPressed,
      child: const Text('Continue with Google'),
    );
  }
}

class _DisabledGoogleButton extends StatelessWidget {
  const _DisabledGoogleButton();

  @override
  Widget build(BuildContext context) {
    return const OutlinedButton(
      onPressed: null,
      child: Text('Continue with Google'),
    );
  }
}
