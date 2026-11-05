import 'dart:async';

/// A timer that never runs by itself. The test calls [fire].
final class FakeTimer implements Timer {
  FakeTimer(this.delay, this._onFire);

  final Duration delay;
  final void Function() _onFire;

  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) {
      return;
    }
    fired = true;
    _onFire();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

/// Use `timers.create` as the `DebounceTimerFactory`.
final class FakeDebounceTimers {
  final List<FakeTimer> created = <FakeTimer>[];

  FakeTimer get last => created.last;

  Timer create(Duration delay, void Function() onFire) {
    final FakeTimer timer = FakeTimer(delay, onFire);
    created.add(timer);
    return timer;
  }
}
