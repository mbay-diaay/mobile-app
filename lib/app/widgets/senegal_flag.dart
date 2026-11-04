import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Drapeau du Sénégal dessiné (vert, or, rouge et étoile verte) : aucune image à charger.
class SenegalFlag extends StatelessWidget {
  const SenegalFlag({super.key, this.size = const Size(22, 15)});
  final Size size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(size: size, painter: const _SenegalFlagPainter()),
      );
}

class _SenegalFlagPainter extends CustomPainter {
  const _SenegalFlagPainter();

  static const _green = Color(0xFF00853F);
  static const _gold = Color(0xFFFDEF42);
  static const _red = Color(0xFFE31B23);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 3;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, size.height), Paint()..color = _green);
    canvas.drawRect(
        Rect.fromLTWH(w, 0, w, size.height), Paint()..color = _gold);
    canvas.drawRect(Rect.fromLTWH(2 * w, 0, size.width - 2 * w, size.height),
        Paint()..color = _red);

    // Étoile à cinq branches au centre de la bande or.
    final c = size.center(Offset.zero);
    final outer = size.height * .3;
    final inner = outer * .4;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = _green);
  }

  @override
  bool shouldRepaint(_SenegalFlagPainter old) => false;
}
