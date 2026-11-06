import 'dart:async';

import 'package:flutter/widgets.dart';

import 'location_service.dart';
import 'sos_sender.dart';

/// Where one SOS activation stands. The SOS screens show one view per phase.
enum SosPhase {
  /// Nothing is happening.
  idle,

  /// Looking up the default contact and the location permission.
  checking,

  /// No default contact is set. Nothing will be sent; show the fallback
  /// (call emergency services or open contacts, PBI-21 AC 1).
  noDefaultContact,

  /// The app has never asked for location. Show the explanation, then call
  /// [SosController.continueAfterExplanation] (PBI-23 AC 1).
  explainLocation,

  /// The system permission dialog is showing.
  requestingPermission,

  /// Counting down; [SosController.secondsLeft] says how long is left.
  countingDown,

  /// The alert is being sent. It can no longer be cancelled.
  sending,

  /// Sending ended; [SosController.result] says how.
  finished,

  /// Cancelled by the user or by leaving the app. Nothing was sent.
  cancelled,
}

enum SosCancelReason {
  /// The user pressed Cancel.
  user,

  /// The app was closed, sent to the background or otherwise interrupted
  /// before the countdown ended (PBI-22 AC 5).
  interrupted,
}

/// Runs one SOS activation: the checks, the countdown, cancel and send now
/// (PBI-22), and hands over to the [SosSender] when the countdown ends.
///
/// The guarantee of PBI-22 AC 5 comes from three things:
/// * The countdown only exists in memory. If the app is closed, the timer
///   dies with it and nothing is saved that could send the alert later.
/// * If the app goes to the background (home button, app switcher, incoming
///   call screen, opening settings), the countdown is cancelled at once.
/// * [SosSender.send] is only called from [_send], which checks that this
///   activation is still the live one.
///
/// Use one controller per SOS screen and dispose it with the screen;
/// disposing also cancels.
class SosController extends ChangeNotifier with WidgetsBindingObserver {
  SosController({
    required SosSender sender,
    required LocationService locationService,
    required Future<String?> Function() loadDefaultContactName,
    this.countdownSeconds = defaultCountdownSeconds,
  })  : assert(countdownSeconds > 0),
        _sender = sender, // ignore: prefer_initializing_formals
        _location = locationService,
        // ignore: prefer_initializing_formals
        _loadDefaultContactName = loadDefaultContactName;

  /// PBI-22 asks for "a few seconds". Five also matches the location limit,
  /// so the fix is usually ready by the time the countdown ends.
  static const int defaultCountdownSeconds = 5;

  final int countdownSeconds;
  final SosSender _sender;
  final LocationService _location;
  final Future<String?> Function() _loadDefaultContactName;

  SosPhase _phase = SosPhase.idle;
  int _secondsLeft = 0;
  String? _contactName;
  LocationStatus? _expectedLocationProblem;
  SosResult? _result;
  SosCancelReason? _cancelReason;

  /// Increases with every activation and every cancel. Async work started
  /// for an older value must stop, so a late answer can never send.
  int _run = 0;
  Timer? _timer;
  Future<LocationResult>? _pendingLocation;
  bool _observing = false;
  bool _disposed = false;

  SosPhase get phase => _phase;
  int get secondsLeft => _secondsLeft;

  /// The default contact's name, for the countdown screen (PBI-22 AC 1).
  String? get contactName => _contactName;

  /// Set during the countdown when it is already known that the alert will
  /// go without a location: [LocationStatus.servicesOff],
  /// [LocationStatus.denied] or [LocationStatus.deniedForever]. The screen
  /// says so and offers a way to turn it on (PBI-23 AC 5). Opening the
  /// settings leaves the app, which cancels the countdown.
  LocationStatus? get expectedLocationProblem => _expectedLocationProblem;

  SosResult? get result => _result;
  SosCancelReason? get cancelReason => _cancelReason;

  /// Whether the user can still stop the alert.
  bool get canCancel => const {
        SosPhase.checking,
        SosPhase.noDefaultContact,
        SosPhase.explainLocation,
        SosPhase.countingDown,
      }.contains(_phase);

  /// Called when the SOS button is pressed.
  Future<void> activate() async {
    if (_disposed) return;
    if (_phase != SosPhase.idle &&
        _phase != SosPhase.finished &&
        _phase != SosPhase.cancelled) {
      return; // already running; a double tap does nothing
    }
    final run = ++_run;
    _result = null;
    _cancelReason = null;
    _expectedLocationProblem = null;
    _contactName = null;
    _startObserving();
    _setPhase(SosPhase.checking);

    String? name;
    try {
      name = await _loadDefaultContactName();
    } catch (_) {
      name = null;
    }
    if (run != _run) return;
    if (name == null || name.trim().isEmpty) {
      _stopObserving();
      _setPhase(SosPhase.noDefaultContact);
      return;
    }
    _contactName = name;

    final needsExplanation = await _location.needsExplanation();
    if (run != _run) return;
    if (needsExplanation) {
      _setPhase(SosPhase.explainLocation);
      return;
    }
    await _startCountdown(run);
  }

  /// Called from the explanation screen's continue button. Shows the system
  /// dialog, then starts the countdown whatever the answer, because SOS
  /// works without a location too (PBI-23 AC 3).
  Future<void> continueAfterExplanation() async {
    if (_phase != SosPhase.explainLocation) return;
    final run = _run;
    _setPhase(SosPhase.requestingPermission);
    await _location.requestPermission();
    if (run != _run) return;
    await _startCountdown(run);
  }

  Future<void> _startCountdown(int run) async {
    // Start the fix now so it overlaps the countdown. It is bounded by the
    // 5-second limit and never throws.
    _pendingLocation = _location.getCurrentLocation();
    _expectedLocationProblem = await _knownLocationProblem();
    if (run != _run) return;

    _secondsLeft = countdownSeconds;
    _setPhase(SosPhase.countingDown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (run != _run) {
        timer.cancel();
        return;
      }
      _secondsLeft -= 1;
      if (_secondsLeft <= 0) {
        timer.cancel();
        _send(run);
      } else {
        notifyListeners();
      }
    });
  }

  Future<LocationStatus?> _knownLocationProblem() async {
    if (!await _location.isLocationServiceEnabled()) {
      return LocationStatus.servicesOff;
    }
    switch (await _location.permissionState()) {
      case LocationPermissionState.granted:
        return null;
      case LocationPermissionState.deniedForever:
        return LocationStatus.deniedForever;
      case LocationPermissionState.notRequested:
      case LocationPermissionState.denied:
        return LocationStatus.denied;
    }
  }

  /// The "Send now" control (PBI-22 AC 4).
  void sendNow() {
    if (_phase != SosPhase.countingDown) return;
    _timer?.cancel();
    _send(_run);
  }

  /// The Cancel control, and also what leaving the screen does. Nothing is
  /// sent and nothing is recorded (PBI-22 AC 2).
  void cancel() => _cancel(SosCancelReason.user);

  void _cancel(SosCancelReason reason) {
    if (!canCancel && _phase != SosPhase.requestingPermission) return;
    _run++;
    _timer?.cancel();
    _timer = null;
    _pendingLocation = null;
    _cancelReason = reason;
    _stopObserving();
    _setPhase(SosPhase.cancelled);
  }

  /// The Retry control on the failure screen (PBI-24 AC 3). Sends again at
  /// once, without a second countdown.
  Future<void> retry() async {
    if (_phase != SosPhase.finished || _result?.wasSent == true) return;
    final run = ++_run;
    _pendingLocation = _location.getCurrentLocation();
    await _send(run);
  }

  Future<void> _send(int run) async {
    if (run != _run || _disposed) return;
    _stopObserving(); // once sending starts, leaving the app cannot stop it
    _setPhase(SosPhase.sending);

    final location = await (_pendingLocation ?? _location.getCurrentLocation());
    _pendingLocation = null;
    // No cancel check here: once the countdown has ended the alert must go
    // out (PBI-22 AC 3), even if the screen is closed meanwhile.

    SosResult result;
    try {
      result = await _sender.send(location: location);
    } catch (_) {
      result = SosResult(outcome: SosOutcome.failed, contactName: _contactName);
    }
    if (_disposed) return;
    _result = result;
    _setPhase(SosPhase.finished);
  }

  /// Back to [SosPhase.idle] after the outcome has been dismissed.
  void reset() {
    if (_phase == SosPhase.sending) return;
    _run++;
    _timer?.cancel();
    _stopObserving();
    _result = null;
    _cancelReason = null;
    _setPhase(SosPhase.idle);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "inactive" is not counted: it also fires for the system permission
    // dialog and for pulling down the notification shade. Leaving the app
    // always passes through "hidden" and "paused".
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_phase == SosPhase.requestingPermission) return;
      _cancel(SosCancelReason.interrupted);
    }
  }

  void _startObserving() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void _stopObserving() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  void _setPhase(SosPhase phase) {
    _phase = phase;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_phase != SosPhase.sending) {
      _run++; // nothing that was waiting may send after the screen is gone
    }
    _timer?.cancel();
    _stopObserving();
    _disposed = true;
    super.dispose();
  }
}
