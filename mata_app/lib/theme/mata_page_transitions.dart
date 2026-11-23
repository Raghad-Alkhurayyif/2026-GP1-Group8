import 'package:flutter/material.dart';

/// Android's own slide-and-fade between screens, drawn from a still picture
/// of each screen while it moves.
///
/// During a slide both screens are on show, each with its artwork, glow and
/// frosted panels, so redrawing them on every frame is the heaviest moment in
/// the app. A picture of each screen is taken when the slide starts and moved
/// instead, as Android's zoom transition does. The background animations rest
/// for the slide and carry on where they stopped.
class MataPageTransitionsBuilder extends PageTransitionsBuilder {
  const MataPageTransitionsBuilder();

  static const PageTransitionsBuilder _android =
      PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _android.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _android.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _android.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      _StillWhileMoving(
        enabled: route.allowSnapshotting,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }
}

class _StillWhileMoving extends StatefulWidget {
  const _StillWhileMoving({
    required this.enabled,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final bool enabled;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_StillWhileMoving> createState() => _StillWhileMovingState();
}

class _StillWhileMovingState extends State<_StillWhileMoving> {
  final SnapshotController _controller = SnapshotController();

  @override
  void initState() {
    super.initState();
    _listen(widget.animation, widget.secondaryAnimation);
    _update();
  }

  @override
  void didUpdateWidget(_StillWhileMoving oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _unlisten(oldWidget.animation, oldWidget.secondaryAnimation);
      _listen(widget.animation, widget.secondaryAnimation);
    }
    _update();
  }

  @override
  void dispose() {
    _unlisten(widget.animation, widget.secondaryAnimation);
    _controller.dispose();
    super.dispose();
  }

  void _listen(Animation<double> a, Animation<double> b) {
    a.addStatusListener(_onStatus);
    b.addStatusListener(_onStatus);
  }

  void _unlisten(Animation<double> a, Animation<double> b) {
    a.removeStatusListener(_onStatus);
    b.removeStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus _) => setState(_update);

  bool get _moving =>
      widget.enabled &&
      (widget.animation.isAnimating || widget.secondaryAnimation.isAnimating);

  void _update() => _controller.allowSnapshotting = _moving;

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      controller: _controller,
      mode: SnapshotMode.permissive,
      child: TickerMode(enabled: !_moving, child: widget.child),
    );
  }
}
