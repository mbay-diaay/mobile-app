import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Anneau de progression (téléchargement 62 %, compte à rebours).
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.size,
    required this.thickness,
    required this.color,
    required this.track,
    required this.inner,
    this.child,
  });

  final double value;
  final double size;
  final double thickness;
  final Color color;
  final Color track;
  final Color inner;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter:
              _RingPainter(value.clamp(0, 1), thickness, color, track, inner),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.thickness, this.color, this.track, this.inner);
  final double value;
  final double thickness;
  final Color color;
  final Color track;
  final Color inner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * value,
      true,
      Paint()..color = color,
    );
    canvas.drawCircle(c, r - thickness, Paint()..color = inner);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
