import 'dart:async';

import 'package:apply_track/core/notifications/notification_scheduler.dart';
import 'package:apply_track/core/notifications/notification_scheduler_provider.dart';
import 'package:apply_track/features/auth/state/auth_controller.dart';
import 'package:apply_track/features/auth/state/auth_state.dart';
import 'package:apply_track/features/proposals/domain/proposal_id.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens a proposal when the user taps its reminder.
///
/// The payload is untrusted input: only a GUID is used. The id waits as
/// "pending" until it is safe to navigate:
/// - the user is signed in, and
/// - the router has left the startup, login and sign up pages.
///
/// So a tap while the session is loading, or while signed out, is not lost.
/// It opens the proposal after the router reaches the app.
final class NotificationTapRouter {
  new({
    required this._scheduler,
    required this._router,
    required this._isSignedIn,
  });

  /// The pages where the auth guard still moves the user.
  static const Set<String> _guardPaths = <String>{
    '',
    AppRoutes.startup,
    AppRoutes.login,
    AppRoutes.signup,
  };

  final NotificationScheduler _scheduler;
  final GoRouter _router;
  final bool Function() _isSignedIn;

  StreamSubscription<String>? _subscription;
  String? _pendingId;
  bool _openScheduled = false;
  bool _disposed = false;

  /// Listens to taps, and reads the tap that started the app (if any).
  void start() {
    _subscription = _scheduler.taps.listen(_onPayload);
    _router.routerDelegate.addListener(requestOpen);
    unawaited(_readLaunchPayload());
  }

  /// Call it when the auth state changes. The router calls it by itself when
  /// the location changes.
  void requestOpen() {
    if (_disposed || _pendingId == null || _openScheduled) {
      return;
    }
    _openScheduled = true;
    // Never navigate inside a router notification.
    scheduleMicrotask(_open);
  }

  void dispose() {
    _disposed = true;
    _router.routerDelegate.removeListener(requestOpen);
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  Future<void> _readLaunchPayload() async {
    final payload = await _scheduler.launchPayload();
    if (payload != null) {
      _onPayload(payload);
    }
  }

  void _onPayload(String payload) {
    if (_disposed || !ProposalId.isValid(payload)) {
      return;
    }
    _pendingId = payload;
    requestOpen();
  }

  void _open() {
    _openScheduled = false;
    final id = _pendingId;
    if (_disposed || id == null || !_isSignedIn()) {
      return;
    }
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (_guardPaths.contains(path)) {
      // The router is still moving. It tells us when the location changes.
      return;
    }
    _pendingId = null;
    final target = AppRoutes.proposal(id);
    if (path != target) {
      unawaited(_router.push<void>(target));
    }
  }
}

/// The app root watches this provider, so it is alive for the whole run.
final Provider<void> notificationTapRouterProvider = Provider<void>((ref) {
  final tapRouter = NotificationTapRouter(
    scheduler: ref.read(notificationSchedulerProvider),
    router: ref.read(appRouterProvider),
    isSignedIn: () => ref.read(authControllerProvider) is AuthSignedIn,
  )..start();
  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) => tapRouter.requestOpen(),
  );
  ref.onDispose(tapRouter.dispose);
});
