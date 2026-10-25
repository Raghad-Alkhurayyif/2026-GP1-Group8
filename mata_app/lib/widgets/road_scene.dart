import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// How the guiding path looks on a given screen.
class RoadMood {
  const RoadMood({
    required this.sky,
    required this.horizon,
    required this.speed,
    required this.curve,
    required this.hills,
    this.lamps = false,
  });

  /// 0 is dusk, 0.5 a warm twilight, 1 full morning light.
  final double sky;

  /// Height of the horizon, as a share of the screen height.
  final double horizon;
  final double speed;
  final double curve;
  final double hills;

  /// Whether the orbs above the path light up one by one (analyzing).
  final bool lamps;

  static const RoadMood welcome = RoadMood(
    sky: .5,
    horizon: .55,
    speed: .12,
    curve: 1,
    hills: 0,
  );

  static const RoadMood signIn = RoadMood(
    sky: .52,
    horizon: .36,
    speed: .05,
    curve: 1,
    hills: 0,
  );

  static const RoadMood analyzing = RoadMood(
    sky: 1,
    horizon: .47,
    speed: 0,
    curve: .35,
    hills: 1,
    lamps: true,
  );
}

/// The guiding path: a floating ribbon of light that twists like the logo's
/// swoosh and runs to a warm horizon.
class RoadScene extends StatefulWidget {
  const RoadScene({required this.mood, super.key});

  final RoadMood mood;

  @override
  State<RoadScene> createState() => _RoadSceneState();
}

class _RoadSceneState extends State<RoadScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _RoadState _state = _RoadState();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = math.min(.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _state.advance(dt, widget.mood);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RoadPainter(_state, widget.mood),
        size: Size.infinite,
      ),
    );
  }
}

class _Mote {
  _Mote(math.Random r)
    : x = (r.nextDouble() - .5) * 9,
      y = r.nextDouble() * 2.6,
      d = 2 + r.nextDouble() * 70;

  double x;
  double y;
  double d;
}

class _RoadState extends ChangeNotifier {
  final math.Random _random = math.Random(7);
  late final List<_Mote> dust = List.generate(70, (_) => _Mote(_random));

  double t = 0;
  double z = 0;
  double lamps = 0;

  void advance(double dt, RoadMood mood) {
    t += dt;
    z += mood.speed * dt * 22;
    if (mood.lamps) lamps = math.min(12, t * 4.2);

    final step = mood.speed * dt * 22 + dt * .25;
    for (final q in dust) {
      q.d -= step;
      if (q.d < .8) {
        q.d = 50 + _random.nextDouble() * 30;
        q.x = (_random.nextDouble() - .5) * 9;
        q.y = _random.nextDouble() * 2.6;
      }
    }
    notifyListeners();
  }
}

// three moods: dusk, a warm twilight in the middle, and first light
const Map<String, List<int>> _palette = {
  'top': [0x141011, 0x3A2A26, 0xE6D7C6],
  'mid': [0x2C201D, 0x6A4C40, 0xF2E7DA],
  'hor': [0x8C6853, 0xC99A78, 0xFFF4E4],
  'sun': [0xD9B18C, 0xE8BE96, 0xFFFAF1],
  'gFar': [0x5E4134, 0x7C5E4E, 0xEEE2D2],
  'gNear': [0x1F1513, 0x33241F, 0xD6C1A8],
  'road': [0xA0714F, 0xB88B66, 0xD9BC9A],
  'edge': [0xFBE0BA, 0xFBE3C4, 0xFFFDF8],
  'dFar': [0x7D5544, 0x9A7764, 0xEADCCA],
  'dNear': [0x3A2823, 0x5E443A, 0xD9C4AA],
  'dash': [0xFFE2B8, 0xFFE2BC, 0xF3C98F],
  'lamp': [0xFFD49A, 0xFFD49E, 0xE9A866],
};

Color _hex(int v) => Color(0xFF000000 | v);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Color _tone(String key, double s) {
  final c = _palette[key]!;
  return s < .5
      ? _mix(_hex(c[0]), _hex(c[1]), s * 2)
      : _mix(_hex(c[1]), _hex(c[2]), (s - .5) * 2);
}

Color _a(Color c, double alpha) => c.withValues(alpha: alpha.clamp(0.0, 1.0));

class _Point {
  _Point(this.d, this.sc, this.x, this.y, this.gy, this.w, this.fog);

  final double d;
  final double sc;
  final double x;
  final double y;
  final double gy;
  final double w;
  final double fog;
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.state, this.mood) : super(repaint: state);

  final _RoadState state;
  final RoadMood mood;

  static const double _camH = 1.6;
  static const double _half = .36;
  static const double _near = 1.2;
  static const double _far = 140;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = mood.sky;
    final f = h * .95;
    final hy = h * mood.horizon;
    final vpX = w / 2;
    final z = state.z;
    final tm = state.t;
    final hor = _tone('hor', s);
    final full = Offset.zero & size;

    // sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, hy + 1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_tone('top', s), _tone('mid', s), hor],
          stops: const [0, .62, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, hy)),
    );

    // the light waiting at the end of the path
    canvas.save();
    canvas.translate(vpX, hy);
    canvas.scale(1, .3 + .7 * s);
    final sun = _tone('sun', s);
    final glowR = h * (.75 - .15 * s);
    canvas.drawRect(
      Rect.fromLTWH(-w * 2, -h * 2, w * 4, h * 4),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(sun, .55 + .4 * s),
            _a(sun, .22 + .28 * s),
            _a(sun, .07 + .05 * s),
            _a(sun, 0),
          ],
          stops: const [0, .12, .4, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: glowR)),
    );
    canvas.restore();

    // soft hills that appear only once the light has arrived
    final hillAlpha = mood.hills * ((s - .25) / .6).clamp(0.0, 1.0);
    if (hillAlpha > 0) {
      const amps = [.06, .04, .026];
      for (var k = 0; k < 3; k++) {
        final amp = amps[k] * h;
        final col = _mix(_tone('dFar', s), _tone('dNear', s), k / 2);
        final off = z * .004 * (k + 1) + k * 1.7;
        final path = Path()..moveTo(0, hy + 2);
        for (double x = 0; x <= w + 6; x += 6) {
          final u = x / w;
          final y =
              hy -
              amp *
                  (.55 + .45 * math.sin(u * 6.1 + off)) *
                  (.45 + .55 * math.sin(u * 2.3 + off * .6 + k));
          path.lineTo(x, y);
        }
        path
          ..lineTo(w, hy + 2)
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = _a(_mix(col, hor, (2 - k) * .18), hillAlpha),
        );
      }
    }

    // ground
    canvas.drawRect(
      Rect.fromLTWH(0, hy, w, h - hy),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _mix(_tone('gFar', s), hor, .35),
            _tone('gFar', s),
            _tone('gNear', s),
          ],
          stops: const [0, .25, 1],
        ).createShader(Rect.fromLTWH(0, hy, w, h - hy)),
    );

    // the path itself
    const n = 170;
    final body = _tone('road', s);
    final edge = _tone('edge', s);
    final core = _tone('dash', s);
    final lc = _tone('lamp', s);
    final litTo = 3.4 + math.max(0, state.lamps - 1) * 3.4;

    double xAt(double d, double sc) {
      final u = 1 - _near / d;
      return vpX +
          mood.curve *
              w *
              .42 *
              math.sin(u * 5.2 + z * .025 + 1.1) *
              math.pow(1 - u, .9);
    }

    double liftAt(double d) => .36 + .2 * math.sin((d + z) * .09 + tm * .7);

    final pts = <_Point>[];
    for (var i = 0; i <= n; i++) {
      final d = _far * math.pow(_near / _far, i / n);
      final sc = f / d;
      final width =
          _half *
          (.16 + .84 * math.cos((d + z) * .05 + .6).abs()) *
          (.3 + .7 * math.min(1, (d - _near) / 7));
      pts.add(
        _Point(
          d,
          sc,
          xAt(d, sc),
          hy + (_camH - liftAt(d)) * sc,
          hy + _camH * sc,
          width,
          1 - math.exp(-d / 34),
        ),
      );
    }
    final vis = pts.where((q) => q.y < h + 60).toList();

    Path outline(List<_Point> list, double k, {bool ground = false}) {
      final path = Path();
      for (var i = 0; i < list.length; i++) {
        final q = list[i];
        final x = q.x - k * q.w * q.sc;
        final y = ground ? q.gy : q.y;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      for (var i = list.length - 1; i >= 0; i--) {
        final q = list[i];
        path.lineTo(q.x + k * q.w * q.sc, ground ? q.gy : q.y);
      }
      return path..close();
    }

    final pathRect = Rect.fromLTWH(0, hy, w, h - hy);
    Shader fade(Color c0, double a0, double a1) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_a(hor, 0), _a(_mix(c0, hor, .5), a0 * .7), _a(c0, a1)],
        stops: const [0, .12, 1],
      ).createShader(pathRect);
    }

    // soft shadow on the ground, so the path reads as floating
    canvas.drawPath(
      outline(vis, 1.4, ground: true),
      Paint()
        ..color = _a(const Color(0xFF281A14), .10 + .04 * s)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // glow
    canvas.drawPath(
      outline(vis, 1),
      Paint()
        ..color = _a(lc, .4 + .05 * s)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (18 + 8 * s) / 2),
    );
    canvas.drawPath(outline(vis, 1), Paint()..shader = fade(body, .55, .85));
    // body
    canvas.drawPath(
      outline(vis, 1),
      Paint()..shader = fade(_mix(body, edge, .25), .7, .95),
    );
    canvas.drawPath(outline(vis, .45), Paint()..shader = fade(edge, .25, .5));

    // the stretch already lit by the orbs
    if (state.lamps > .05) {
      final lit = vis.where((q) => q.d <= litTo + 1.7).toList();
      if (lit.length > 1) {
        canvas.drawPath(
          outline(lit, 1),
          Paint()
            ..color = _a(lc, .95)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
        );
        canvas.drawPath(
          outline(lit, 1),
          Paint()
            ..shader = fade(_mix(lc, const Color(0xFFFFFAEE), .35), .8, .9),
        );
      }
    }

    // bright edges and a centre thread
    void line(double k, double width, double alpha) {
      final path = Path();
      var started = false;
      for (final q in pts) {
        if (q.y > h + 40) break;
        final x = q.x + k * q.w * q.sc;
        started ? path.lineTo(x, q.y) : path.moveTo(x, q.y);
        started = true;
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_a(edge, 0), _a(edge, alpha * .6), _a(edge, alpha)],
            stops: const [0, .18, 1],
          ).createShader(pathRect),
      );
    }

    line(-1, 1.3, .9);
    line(1, 1.3, .9);
    line(0, .8, .35);

    // pulses of light travelling ahead, showing the way
    for (var k = 0; k < 5; k++) {
      final d = _near + 2 + ((k * 15 + tm * 7) % 75);
      final sc = f / d;
      final fog = 1 - math.exp(-d / 34);
      final x = xAt(d, sc);
      final y = hy + (_camH - liftAt(d)) * sc;
      final r = math.max(3.0, .5 * sc);
      final a = (1 - fog) * (.55 - .2 * s);
      if (a < .01) continue;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _a(const Color(0xFFFFFAEE), a),
              _a(core, a * .6),
              _a(core, 0),
            ],
            stops: const [0, .25, 1],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
      );
    }

    // orbs above the path that light up one by one while we read
    if (mood.lamps) {
      for (var j = 0; j < 12; j++) {
        final d = 3.4 + j * 3.4;
        final sc = f / d;
        final fog = 1 - math.exp(-d / 34);
        final lit = (state.lamps - j).clamp(0.0, 1.0);
        final x = xAt(d, sc);
        final y =
            hy +
            (_camH - liftAt(d) - .55 - .05 * math.sin(tm * 1.6 + j)) * sc;
        final seen = 1 - fog;
        final r0 = math.max(1.5, .06 * sc);
        canvas.drawCircle(
          Offset(x, y),
          r0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _a(_mix(_tone('dNear', s), edge, .4), .35 * seen),
        );
        if (lit > 0) {
          final r = math.max(6.0, .55 * sc);
          canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  _a(const Color(0xFFFFFBF0), lit * seen + .2 * lit),
                  _a(lc, .85 * lit),
                  _a(lc, 0),
                ],
                stops: const [0, .14, 1],
              ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
          );
        }
      }
    }

    // drifting dust
    final dc = _mix(const Color(0xFFFFE2BA), const Color(0xFF8C6850), s);
    final tail = math.min(18, mood.speed * 7);
    final dustPaint = Paint()..strokeCap = StrokeCap.round;
    for (final q in state.dust) {
      final sc = f / q.d;
      final x = vpX + q.x * sc;
      final y = hy + (_camH - q.y) * sc;
      if (x < -20 || x > w + 20 || y < -20 || y > h + 20) continue;
      final a = math.min(1, 1 - q.d / 80) * .3;
      final sc2 = f / (q.d + tail * .08);
      dustPaint
        ..color = _a(dc, a.toDouble())
        ..strokeWidth = (.035 * sc).clamp(.8, 2.6);
      canvas.drawLine(
        Offset(vpX + q.x * sc2, hy + (_camH - q.y) * sc2),
        Offset(x + .01, y),
        dustPaint,
      );
    }

    // vignette
    final vr = h * .85;
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x000F0806),
            _a(const Color(0xFF0F0806), .42 * (1 - s) + .07),
          ],
          stops: [.3 / .85, 1],
        ).createShader(
          Rect.fromCircle(center: Offset(w / 2, h * .52), radius: vr),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
