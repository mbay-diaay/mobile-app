import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Fond de carte de la maquette : quadrillage de 36 px sur vert pâle.
class MapGridBackground extends StatelessWidget {
  const MapGridBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _GridPainter(), child: child ?? const SizedBox.expand());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapBg);
    final p = Paint()
      ..color = AppColors.mapGrid
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// Un contour de parcelle dans un repère de conception (viewBox).
class PlotShape {
  const PlotShape(this.points,
      {required this.stroke,
      this.fill,
      this.dashed = false,
      this.closed = true});
  final List<Offset> points;
  final Color stroke;
  final Color? fill;
  final bool dashed;
  final bool closed;
}

/// Dessine des contours mis à l'échelle depuis un viewBox, avec un tracé progressif
/// ([progress] de 0 à 1) et, en option, les sommets.
class PlotPainter extends CustomPainter {
  PlotPainter({
    required this.shapes,
    required this.viewBox,
    this.progress = 1,
    this.strokeWidth = 2.5,
    this.showVertices = false,
    this.highlightVertex,
    this.pulse = 0,
  });

  final List<PlotShape> shapes;
  final Size viewBox;
  final double progress;
  final double strokeWidth;
  final bool showVertices;
  final int? highlightVertex;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    // Équivalent de preserveAspectRatio="xMidYMid meet".
    final s = (size.width / viewBox.width) < (size.height / viewBox.height)
        ? size.width / viewBox.width
        : size.height / viewBox.height;
    final dx = (size.width - viewBox.width * s) / 2;
    final dy = (size.height - viewBox.height * s) / 2;
    Offset map(Offset o) => Offset(dx + o.dx * s, dy + o.dy * s);

    for (final shape in shapes) {
      if (shape.points.isEmpty) continue;
      final pts = shape.points.map(map).toList();
      final path = Path()..addPolygon(pts, shape.closed && pts.length > 2);

      if (shape.fill != null && pts.length > 2) {
        canvas.drawPath(
          path,
          Paint()
            ..color = shape.fill!.withValues(
                alpha: shape.fill!.a * Curves.easeIn.transform(progress)),
        );
      }

      final stroke = Paint()
        ..color = shape.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      for (final metric in path.computeMetrics()) {
        final len = metric.length * progress;
        if (shape.dashed) {
          for (double d = 0; d < len; d += 10) {
            canvas.drawPath(
                metric.extractPath(d, (d + 6).clamp(0, len)), stroke);
          }
        } else {
          canvas.drawPath(metric.extractPath(0, len), stroke);
        }
      }

      if (showVertices) {
        for (var i = 0; i < pts.length; i++) {
          final hl = i == highlightVertex;
          if (hl) {
            canvas.drawCircle(
                pts[i],
                9 + 10 * pulse,
                Paint()
                  ..color = shape.stroke.withValues(alpha: .3 * (1 - pulse)));
          }
          canvas.drawCircle(pts[i], hl ? 9 : 6, Paint()..color = Colors.white);
          canvas.drawCircle(
            pts[i],
            hl ? 9 : 6,
            Paint()
              ..color = shape.stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(PlotPainter old) => true;
}

/// Contour qui se dessine à l'apparition.
class AnimatedPlots extends StatelessWidget {
  const AnimatedPlots({
    super.key,
    required this.shapes,
    required this.viewBox,
    this.duration = const Duration(milliseconds: 1400),
    this.strokeWidth = 2.5,
  });

  final List<PlotShape> shapes;
  final Size viewBox;
  final Duration duration;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeInOutCubic,
        builder: (_, t, __) => CustomPaint(
          size: Size.infinite,
          painter: PlotPainter(
              shapes: shapes,
              viewBox: viewBox,
              progress: t,
              strokeWidth: strokeWidth),
        ),
      );
}

/// Aire (en ha) indicative d'un polygone exprimé en pixels de conception.
/// L'échelle est fixée pour retrouver les ordres de grandeur de la maquette.
double indicativeHectares(List<Offset> pts) {
  if (pts.length < 3) return 0;
  double a = 0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a.abs() / 2 / 90000;
}
