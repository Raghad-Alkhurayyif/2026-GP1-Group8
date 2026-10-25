import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The background for the screens inside the app: the original artwork, where
/// the logo's stroke returns across the screen, with a touch of light along its
/// edge and a few slow glints. It holds still so nothing distracts while people
/// type and read.
class StrokeBackground extends StatefulWidget {
  const StrokeBackground({this.glints = true, super.key});

  final bool glints;

  @override
  State<StrokeBackground> createState() => _StrokeBackgroundState();
}

class _StrokeBackgroundState extends State<StrokeBackground>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(0);
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.glints) {
      _ticker = createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      })..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF8F4EE)),
        Image.asset('assets/images/background.png', fit: BoxFit.cover),
        RepaintBoundary(child: CustomPaint(painter: _LightTouchPainter())),
        if (widget.glints)
          RepaintBoundary(
            child: CustomPaint(painter: _GlintPainter(_time)),
          ),
      ],
    );
  }
}

// The lit edge of the original stroke, traced on the 402 x 874 artwork.
const Size _artSize = Size(402, 874);
const List<Offset> _edge = [
  Offset(0, .149),
  Offset(.124, .201),
  Offset(.249, .265),
  Offset(.373, .323),
  Offset(.498, .367),
  Offset(.622, .412),
  Offset(.746, .45),
  Offset(.871, .486),
  Offset(.995, .513),
];

/// Maps the traced edge onto the screen the same way BoxFit.cover places the
/// artwork.
List<Offset> _edgeOnScreen(Size size) {
  final k = math.max(
    size.width / _artSize.width,
    size.height / _artSize.height,
  );
  final w = _artSize.width * k;
  final h = _artSize.height * k;
  final ox = (size.width - w) / 2;
  final oy = (size.height - h) / 2;

  return [for (final p in _edge) Offset(ox + p.dx * w, oy + p.dy * h)];
}

class _LightTouchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final e = _edgeOnScreen(size);

    final path = Path()
      ..moveTo(e.first.dx - 40, e.first.dy - 20)
      ..lineTo(e.first.dx, e.first.dy);
    for (var i = 1; i < e.length; i++) {
      final a = e[i - 1];
      final b = e[i];
      path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    path.lineTo(e.last.dx + 30, e.last.dy + 12);

    // a soft halo along the existing edge
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x99FFF7E8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // a fine glowing line on top of it
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF4DE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xD9FFFEFA),
    );

    // soft blooms where the light catches most
    void bloom(Offset c, double r, double a) {
      final radius = size.width * r;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF8EA).withValues(alpha: a),
              const Color(0x00FFF8EA),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    bloom(e[2], .32, .3);
    bloom(e[6], .26, .22);
  }

  @override
  bool shouldRepaint(covariant _LightTouchPainter oldDelegate) => false;
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;

  static const List<int> _points = [1, 2, 3, 6, 7];

  @override
  void paint(Canvas canvas, Size size) {
    final e = _edgeOnScreen(size);
    final t = time.value;

    for (var k = 0; k < _points.length; k++) {
      final i = _points[k];
      final q = e[i];
      final u = i / 8;
      final wave = .5 + .5 * math.sin(t * (.55 + k * .11) + k * 2.3);
      final a = math.pow(wave, 4) * .9;
      if (a < .02) continue;
      final r = 1.6 + u * 1.4;

      canvas.drawCircle(
        q,
        r * 7,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFDF6).withValues(alpha: a.toDouble()),
              const Color(0x00FFF0D7),
            ],
          ).createShader(Rect.fromCircle(center: q, radius: r * 7)),
      );
      final cross = Paint()
        ..color = const Color(0xFFFFFCF4).withValues(alpha: a * .7)
        ..strokeWidth = .7;
      canvas.drawLine(q.translate(-r * 5, 0), q.translate(r * 5, 0), cross);
      canvas.drawLine(q.translate(0, -r * 5), q.translate(0, r * 5), cross);
    }
  }

  @override
  bool shouldRepaint(covariant _GlintPainter oldDelegate) => false;
}
