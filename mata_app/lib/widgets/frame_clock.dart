import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Calls [onFrame] on screen refreshes, at most [fps] times a second.
///
/// Slow background motion looks the same at 30 frames a second. Asking for
/// fewer frames spares the phone from redrawing the whole screen, frosted
/// panels included, on every refresh.
class FrameClock {
  FrameClock({required this.fps, required this.onFrame});

  final int fps;

  /// Receives the time the clock has been running, pauses excluded.
  final void Function(Duration elapsed) onFrame;

  // Wake a little early, so the next frame lands on the refresh that is due.
  static const Duration _margin = Duration(milliseconds: 4);

  Duration get _interval => Duration(microseconds: 1000000 ~/ fps);

  Duration? _start;
  Duration _carried = Duration.zero;
  Duration _last = Duration.zero;
  Timer? _wait;
  int? _callbackId;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _request();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _wait?.cancel();
    _wait = null;
    if (_callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_callbackId!);
      _callbackId = null;
    }
    _carried = _last;
    _start = null;
  }

  void dispose() => stop();

  void _request() {
    _callbackId = SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration timeStamp) {
    _callbackId = null;
    if (!_running) return;
    _start ??= timeStamp - _carried;
    _last = timeStamp - _start!;
    onFrame(_last);
    _wait = Timer(_interval - _margin, () {
      _wait = null;
      if (_running) _request();
    });
  }
}
