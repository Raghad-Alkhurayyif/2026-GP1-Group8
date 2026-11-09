import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_contact_service.dart';
import '../sos/location_service.dart';
import '../sos/sos_controller.dart';
import '../sos/sos_sender.dart';
import '../sos/sos_setup.dart';
import '../theme/mata_theme.dart';
import '../widgets/road_scene.dart';
import 'emergency_contacts_screen.dart';

/// Opens the SOS flow from any screen (PBI-19). The flow starts at once:
/// there is no menu or contact choice in between.
Future<void> openSos(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => const SosScreen(),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// One SOS activation: the checks, the location explanation, the
/// countdown with cancel and send now, sending, and the outcome
/// (PBI-21 to PBI-24). The logic is in [SosController]; this screen only
/// shows its phases.
class SosScreen extends StatefulWidget {
  const SosScreen({
    this.sender,
    this.locationService,
    this.contactService,
    super.key,
  });

  /// Left out in the app; passed in for previews.
  final SosSender? sender;
  final LocationService? locationService;
  final EmergencyContactService? contactService;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  late final SosSender _sender = widget.sender ?? createSosSender();
  late final LocationService _location =
      widget.locationService ?? LocationService();
  late final SosController _controller = createSosController(
    sender: _sender,
    locationService: _location,
    contactService: widget.contactService,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.activate();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    // A cancel by the user returns to the previous screen (PBI-22 AC 2).
    if (_controller.phase == SosPhase.cancelled &&
        _controller.cancelReason == SosCancelReason.user) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _callEmergencyServices() async {
    bool opened;
    try {
      opened = await launchUrl(
        Uri(scheme: 'tel', path: emergencyServicesNumber),
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please call $emergencyServicesNumber from your phone.',
            style: MataText.body(color: MataColors.softWhite),
          ),
        ),
      );
    }
  }

  void _openContacts() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EmergencyContactsScreen(service: widget.contactService),
      ),
    );
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final phase = _controller.phase;

    return PopScope(
      // While sending, the alert goes out regardless, so stay and show it.
      canPop: phase != SosPhase.sending,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _controller.canCancel) _controller.cancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF140E0F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RoadScene(mood: RoadMood.sos),
            const _Scrim(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: KeyedSubtree(
                    key: ValueKey(_viewKey(phase)),
                    child: _buildPhase(phase),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _viewKey(SosPhase phase) => switch (phase) {
        SosPhase.idle || SosPhase.checking => 'checking',
        SosPhase.explainLocation || SosPhase.requestingPermission => 'explain',
        SosPhase.finished => 'finished-${_controller.result?.outcome.name}',
        _ => phase.name,
      };

  Widget _buildPhase(SosPhase phase) {
    switch (phase) {
      case SosPhase.idle:
      case SosPhase.checking:
        return const _Preparing();
      case SosPhase.noDefaultContact:
        return _noDefaultContact();
      case SosPhase.explainLocation:
      case SosPhase.requestingPermission:
        return _explainLocation(phase == SosPhase.requestingPermission);
      case SosPhase.countingDown:
        return _countdown();
      case SosPhase.sending:
        return _sending();
      case SosPhase.finished:
        return _finished();
      case SosPhase.cancelled:
        return _interrupted();
    }
  }

  String get _contactName =>
      _controller.contactName ??
      _controller.result?.contactName ??
      'your contact';

  Widget _noDefaultContact() {
    return _Message(
      icon: Icons.person_off_outlined,
      tone: _Tone.warning,
      title: 'No default SOS contact',
      body: 'Nothing was sent. Choose the contact SOS should alert, or call '
          'emergency services now.',
      actions: [
        MataButton(
          label: 'Call $emergencyServicesNumber',
          icon: Icons.call_rounded,
          style: MataButtonStyle.danger,
          height: 56,
          onPressed: _callEmergencyServices,
        ),
        MataButton(
          label: 'Set Up Emergency Contacts',
          style: MataButtonStyle.ghost,
          onPressed: _openContacts,
        ),
        _TextAction(label: 'Close', onTap: _close),
      ],
    );
  }

  Widget _explainLocation(bool requesting) {
    return _Message(
      icon: Icons.location_on_outlined,
      tone: _Tone.calm,
      title: 'Share your location?',
      body: 'Ma’ta can add your current location to the alert so '
          '$_contactName can find you. It is used only for this alert '
          'and is never stored.',
      note: 'Your phone will ask for permission next. SOS still works if you '
          'decline.',
      actions: [
        MataButton(
          label: 'Continue',
          style: MataButtonStyle.cream,
          loading: requesting,
          onPressed: requesting ? null : _controller.continueAfterExplanation,
        ),
        _TextAction(
          label: 'Cancel SOS',
          onTap: requesting ? null : _controller.cancel,
        ),
      ],
    );
  }

  Widget _countdown() {
    final problem = _controller.expectedLocationProblem;

    return Column(
      children: [
        const _SosMark(),
        const Spacer(flex: 2),
        _CountdownRing(
          secondsLeft: _controller.secondsLeft,
          total: _controller.countdownSeconds,
        ),
        const SizedBox(height: 26),
        Text(
          'Alerting $_contactName',
          textAlign: TextAlign.center,
          style: MataText.display(
            color: MataColors.softWhite,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your alert will be sent when the countdown ends.',
          textAlign: TextAlign.center,
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 18),
          _LocationNotice(
            problem: problem,
            onFix: () => problem == LocationStatus.servicesOff
                ? _location.openLocationSettings()
                : _location.openAppSettings(),
          ),
        ],
        const Spacer(flex: 3),
        // Large and full width, so it can be hit without precision (AC 6).
        MataButton(
          label: 'Cancel',
          style: MataButtonStyle.cream,
          height: 66,
          onPressed: _controller.cancel,
        ),
        const SizedBox(height: 10),
        _TextAction(label: 'Send now', onTap: _controller.sendNow),
      ],
    );
  }

  Widget _sending() {
    return Column(
      children: [
        const _SosMark(),
        const Spacer(flex: 2),
        const _CountdownRing(secondsLeft: null, total: 1),
        const SizedBox(height: 26),
        Text(
          'Sending your alert',
          textAlign: TextAlign.center,
          style: MataText.display(
            color: MataColors.softWhite,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'To $_contactName. This can no longer be cancelled.',
          textAlign: TextAlign.center,
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const Spacer(flex: 4),
      ],
    );
  }

  Widget _finished() {
    final result = _controller.result;
    final testMode = isTestSender(_sender);

    switch (result?.outcome) {
      case SosOutcome.sent:
        return _Message(
          icon: Icons.check_rounded,
          tone: _Tone.success,
          title: 'Alert sent',
          body: '$_contactName has been sent a text message saying you need '
              'help.',
          note: result!.locationIncluded
              ? 'Your location was included.'
              : 'Your location could not be included.',
          footnote:
              testMode ? 'Test mode: no text message was actually sent.' : null,
          actions: [
            MataButton(
              label: 'Done',
              style: MataButtonStyle.cream,
              onPressed: _close,
            ),
          ],
        );
      case SosOutcome.noDefaultContact:
        return _noDefaultContact();
      case SosOutcome.noNetwork:
        return _Message(
          icon: Icons.wifi_off_rounded,
          tone: _Tone.warning,
          title: 'No connection',
          body: 'Your alert could not be sent, so $_contactName was not '
              'notified. Please call emergency services directly.',
          actions: [
            MataButton(
              label: 'Call $emergencyServicesNumber',
              icon: Icons.call_rounded,
              style: MataButtonStyle.danger,
              height: 56,
              onPressed: _callEmergencyServices,
            ),
            MataButton(
              label: 'Try Again',
              style: MataButtonStyle.ghost,
              onPressed: _controller.retry,
            ),
            _TextAction(label: 'Close', onTap: _close),
          ],
        );
      case SosOutcome.failed:
      case null:
        return _Message(
          icon: Icons.priority_high_rounded,
          tone: _Tone.warning,
          title: 'Alert not sent',
          body: '$_contactName was not notified.',
          actions: [
            MataButton(
              label: 'Try Again',
              style: MataButtonStyle.cream,
              onPressed: _controller.retry,
            ),
            MataButton(
              label: 'Call $emergencyServicesNumber',
              icon: Icons.call_rounded,
              style: MataButtonStyle.danger,
              onPressed: _callEmergencyServices,
            ),
            _TextAction(label: 'Close', onTap: _close),
          ],
        );
    }
  }

  Widget _interrupted() {
    return _Message(
      icon: Icons.pause_rounded,
      tone: _Tone.calm,
      title: 'SOS was stopped',
      body: 'You left the app before the countdown ended, so nothing was '
          'sent.',
      actions: [
        MataButton(
          label: 'Start SOS Again',
          style: MataButtonStyle.danger,
          onPressed: _controller.activate,
        ),
        _TextAction(label: 'Close', onTap: _close),
      ],
    );
  }
}

/// Darkens the sky above the path and the ground under the buttons, so the
/// text and the controls read clearly.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE6120C0D),
            Color(0x8C120C0D),
            Color(0x59120C0D),
            Color(0xD9120C0D),
          ],
          stops: [0, 0.5, 0.68, 1],
        ),
      ),
    );
  }
}

/// The small label at the top of the SOS screens.
class _SosMark extends StatelessWidget {
  const _SosMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE5483F),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5483F).withValues(alpha: 0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'EMERGENCY ALERT',
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// A ring of light that drains as the seconds pass. With [secondsLeft] null
/// it turns slowly instead, while the alert is being sent (PBI-24 AC 4).
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft, required this.total});

  final int? secondsLeft;
  final int total;

  static const double _size = 224;

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;

    final Widget ring = seconds == null
        ? const _SpinningRing()
        : TweenAnimationBuilder<double>(
            key: ValueKey(seconds),
            tween: Tween(begin: seconds / total, end: (seconds - 1) / total),
            duration: const Duration(seconds: 1),
            builder: (_, value, _) =>
                CustomPaint(painter: _RingPainter(fraction: value)),
          );

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // a soft red glow behind the ring
          Container(
            width: _size * 0.8,
            height: _size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB71616).withValues(alpha: 0.35),
                  blurRadius: 70,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Positioned.fill(child: ring),
          if (seconds != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$seconds',
                  style: MataText.display(
                    color: MataColors.softWhite,
                    fontSize: 84,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  seconds == 1 ? 'second' : 'seconds',
                  style: MataText.body(
                    color: MataColors.softWhite.withValues(alpha: 0.6),
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            )
          else
            Icon(
              Icons.send_rounded,
              color: MataColors.softWhite.withValues(alpha: 0.85),
              size: 40,
            ),
        ],
      ),
    );
  }
}

class _SpinningRing extends StatefulWidget {
  const _SpinningRing();

  @override
  State<_SpinningRing> createState() => _SpinningRingState();
}

class _SpinningRingState extends State<_SpinningRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, _) => CustomPaint(
        painter: _RingPainter(fraction: 0.28, start: _spin.value),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, this.start = 0});

  /// How much of the ring is lit, from 0 to 1.
  final double fraction;

  /// Where the lit part starts, in turns from the top.
  final double start;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke * 2,
    );

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = MataColors.softWhite.withValues(alpha: 0.14),
    );

    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final from = -math.pi / 2 + start * math.pi * 2;

    final lit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(from),
        colors: const [Color(0xFFFFE3C2), Color(0xFFE5483F)],
        stops: [0, math.max(fraction, 0.01)],
      ).createShader(rect);

    // the glow, then the line itself
    canvas.drawArc(
      rect,
      from,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 3
        ..color = const Color(0xFFE5483F).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(rect, from, sweep, false, lit);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.start != start;
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.problem, required this.onFix});

  final LocationStatus problem;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final servicesOff = problem == LocationStatus.servicesOff;

    return MataNightSheet(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 19,
                color: MataColors.softWhite.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  servicesOff
                      ? 'Location is off on this phone, so the alert will be '
                          'sent without your location.'
                      : 'Ma’ta is not allowed to use your location, so the '
                          'alert will be sent without it.',
                  style: MataText.body(
                    color: MataColors.softWhite.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 29),
              TextButton(
                onPressed: onFix,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  servicesOff ? 'Turn on location' : 'Allow in settings',
                  style: MataText.body(
                    color: const Color(0xFFF3C98F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'This stops the countdown.',
                  style: MataText.body(
                    color: MataColors.softWhite.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SosMark(),
        const Spacer(),
        const SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            color: MataColors.softWhite,
            strokeWidth: 2.4,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Preparing your alert',
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.8),
            fontSize: 15,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

enum _Tone { calm, success, warning }

/// The layout shared by the explanation and the outcome screens.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.actions,
    this.note,
    this.footnote,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String body;
  final String? note;
  final String? footnote;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (Color core, Color halo) = switch (tone) {
      _Tone.calm => (const Color(0xFFFFE6C4), const Color(0xFFE9A866)),
      _Tone.success => (const Color(0xFFFFF1D6), const Color(0xFFE7B871)),
      _Tone.warning => (const Color(0xFFFFD2C8), const Color(0xFFE5483F)),
    };

    return Column(
      children: [
        const _SosMark(),
        const Spacer(flex: 2),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [core, halo.withValues(alpha: 0.85)],
            ),
            boxShadow: [
              BoxShadow(
                color: halo.withValues(alpha: 0.5),
                blurRadius: 46,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, size: 38, color: const Color(0xFF3A2320)),
        ),
        const SizedBox(height: 26),
        Text(
          title,
          textAlign: TextAlign.center,
          style: MataText.display(
            color: MataColors.softWhite,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.78),
            fontSize: 15,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 10),
          Text(
            note!,
            textAlign: TextAlign.center,
            style: MataText.body(
              color: MataColors.softWhite.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: MataColors.softWhite.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              footnote!,
              style: MataText.body(
                color: MataColors.softWhite.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
        const Spacer(flex: 3),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          actions[i],
        ],
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: MataText.body(
            color: MataColors.softWhite.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
