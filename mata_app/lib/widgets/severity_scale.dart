import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mata_theme.dart';

/// A horizontal scale with fixed stops: Mild, Moderate, Severe.
///
/// Tap a stop, or drag along the track and the thumb settles on the nearest
/// one. A null [value] means no severity is chosen ("I'm not sure"), and the
/// scale shows no thumb.
class SeverityScale extends StatelessWidget {
  const SeverityScale({
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const stops = [
    ('Mild', 'low'),
    ('Moderate', 'moderate'),
    ('Severe', 'high'),
  ];

  static const double _thumb = 22;
  static const double _height = 34;

  final String? value;
  final ValueChanged<String> onChanged;

  int? get _index {
    final i = stops.indexWhere((s) => s.$2 == value);
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The first and last stops sit half a thumb in from each edge.
        final inset = _thumb / 2;
        final span = constraints.maxWidth - 2 * inset;
        double xOf(int i) => inset + span * i / (stops.length - 1);

        void select(double dx) {
          final t = ((dx - inset) / span).clamp(0.0, 1.0);
          final i = (t * (stops.length - 1)).round();
          if (stops[i].$2 != value) {
            HapticFeedback.selectionClick();
            onChanged(stops[i].$2);
          }
        }

        final index = _index;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => select(d.localPosition.dx),
          onHorizontalDragStart: (d) => select(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => select(d.localPosition.dx),
          child: Column(
            children: [
              SizedBox(
                height: _height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track.
                    Positioned(
                      left: inset,
                      right: inset,
                      top: _height / 2 - 1.5,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: MataColors.brown.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Filled part, up to the chosen stop.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: inset,
                      width: index == null ? 0 : xOf(index) - inset,
                      top: _height / 2 - 1.5,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              MataColors.brown.withValues(alpha: 0.45),
                              MataColors.brown,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Stops.
                    for (var i = 0; i < stops.length; i++)
                      Positioned(
                        left: xOf(i) - 4,
                        top: _height / 2 - 4,
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index != null && i <= index
                                ? MataColors.brown
                                : MataColors.softWhite,
                            border: Border.all(
                              color: MataColors.brown.withValues(
                                alpha: index != null && i <= index ? 1 : 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Thumb.
                    if (index != null)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        left: xOf(index) - _thumb / 2,
                        top: _height / 2 - _thumb / 2,
                        width: _thumb,
                        height: _thumb,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MataColors.softWhite,
                            border: Border.all(
                              color: MataColors.brown,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MataColors.cocoa.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: MataColors.brown,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < stops.length; i++)
                    Expanded(
                      child: Text(
                        stops[i].$1,
                        textAlign: switch (i) {
                          0 => TextAlign.left,
                          2 => TextAlign.right,
                          _ => TextAlign.center,
                        },
                        style: MataText.body(
                          color: i == index
                              ? MataColors.brown
                              : MataColors.muted,
                          fontSize: 13,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
