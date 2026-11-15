import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/emergency_contact.dart';

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
  preparingSms,

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
    required Future<EmergencyContact?> Function() loadDefaultContact,
    this.countdownSeconds = defaultCountdownSeconds,
  }) : assert(countdownSeconds > 0),
       _sender = sender, // ignore: prefer_initializing_formals
       _location = locationService,
       // ignore: prefer_initializing_formals
       _loadDefaultContact = loadDefaultContact;

  /// PBI-22 asks for "a few seconds". Five also matches the location limit,
  /// so the fix is usually ready by the time the countdown ends.
  static const int defaultCountdownSeconds = 5;

  final int countdownSeconds;
  final SosSender _sender;
  final LocationService _location;
  final Future<EmergencyContact?> Function() _loadDefaultContact;
  EmergencyContact? _contact;
  bool _waitingToDispatch = false;

  SosPhase _phase = SosPhase.idle;
  int _secondsLeft = 0;
  String? _contactName;
  LocationStatus? _expectedLocationProblem;
  SosResult? _result;
  SosCancelReason? _cancelReason;
  LocationResult? _lastLocation;

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

  /// The location fetched for the latest alert, once sending has it. The
  /// screen uses it to pick the emergency number for the country the user
  /// is in. Like the alert itself, it is never stored.
  LocationResult? get lastLocation => _lastLocation;
  SosCancelReason? get cancelReason => _cancelReason;

  /// Whether the user can still stop the alert.
  bool get canCancel => const {
    SosPhase.checking,
    SosPhase.preparingSms,
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
    _contact = null;
    _waitingToDispatch = false;
    _startObserving();
    _setPhase(SosPhase.checking);

    EmergencyContact? contact;
    try {
      contact = await _loadDefaultContact().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      if (run == _run) {
        _finishPreparation(
          const SosResult(
            outcome: SosOutcome.failed,
            reason: 'contact_unavailable',
            retryAllowed: true,
          ),
        );
      }
      return;
    }
    if (run != _run) return;
    if (contact == null) {
      _stopObserving();
      _setPhase(SosPhase.noDefaultContact);
      return;
    }
    _contact = contact;
    _contactName = contact.name;
    if (!await _prepareSms(run)) return;
    await _prepareLocation(run);
  }

  Future<void> _prepareLocation(int run) async {
    final needsExplanation = await _location.needsExplanation();
    if (run != _run) return;
    if (needsExplanation) {
      _setPhase(SosPhase.explainLocation);
      return;
    }
    await _startCountdown(run);
  }

  void _finishPreparation(SosResult result) {
    _result = result;
    _stopObserving();
    _setPhase(SosPhase.finished);
  }

  Future<bool> _prepareSms(int run) async {
    _setPhase(SosPhase.preparingSms);
    SosResult? failure;
    try {
      failure = await _sender.prepare(_contact!);
    } catch (_) {
      failure = SosResult(
        outcome: SosOutcome.failed,
        reason: 'preparation_failed',
        contactName: _contactName,
        retryAllowed: true,
      );
    }
    if (run != _run || _disposed) return false;
    if (failure != null) {
      _finishPreparation(failure);
      return false;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      _cancel(SosCancelReason.interrupted);
      return false;
    }
    return true;
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
    if (run != _run || _disposed) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      _cancel(SosCancelReason.interrupted);
      return;
    }
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

  /// Retry is explicit and only allowed after a known pre-dispatch failure.
  Future<void> retry() async {
    if (_phase != SosPhase.finished || _result?.retryAllowed != true) return;
    // Explicit retry performs preparation and countdown again. Never blindly
    // redispatch a possibly sent alert. Retain this activation's recipient.
    if (_contact == null) {
      await activate();
      return;
    }
    final run = ++_run;
    _result = null;
    _startObserving();
    if (!await _prepareSms(run)) return;
    await _prepareLocation(run);
  }

  Future<void> _send(int run) async {
    if (run != _run ||
        _disposed ||
        _waitingToDispatch ||
        _phase != SosPhase.countingDown) {
      return;
    }
    _waitingToDispatch = true;

    final location = await (_pendingLocation ?? _location.getCurrentLocation());
    _waitingToDispatch = false;
    if (run != _run || _disposed || _phase != SosPhase.countingDown) return;
    _pendingLocation = null;
    _lastLocation = location;
    _stopObserving();
    _setPhase(SosPhase.sending);

    SosResult result;
    try {
      result = await _sender.send(location: location);
    } catch (_) {
      result = SosResult(
        outcome: SosOutcome.unknown,
        contactName: _contactName,
      );
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
      if (_phase == SosPhase.requestingPermission ||
          _phase == SosPhase.preparingSms) {
        return;
      }
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
