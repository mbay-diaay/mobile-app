import 'package:flutter/material.dart';

/// Palette de la maquette v2 : vert forêt, citron, crème.
abstract final class AppColors {
  static const forest = Color(0xFF0F3D2A);
  static const forestLight = Color(0xFF1C5A3E);
  static const forestDeep = Color(0xFF0A2B1D);
  static const lime = Color(0xFFC6F05A);
  static const cream = Color(0xFFF5F2EA);
  static const ink = Color(0xFF0E1A14);
  static const inkSoft = Color(0xFF2C3A33);
  static const muted = Color(0xFF5B6660);
  static const faint = Color(0xFFB9C0BB);
  static const gray = Color(0xFF8A928D);
  static const sage = Color(0xFFEEF3E4);
  static const sand = Color(0xFFE6E2D6);
  static const divider = Color(0xFFEFECE3);
  static const handle = Color(0xFFC9C4B6);

  static const coral = Color(0xFFFF6B6B);
  static const maroon = Color(0xFF2A1012);
  static const maroonMid = Color(0xFF5A1A1C);
  static const maroonDeep = Color(0xFF1A0B0C);
  static const maroonRing = Color(0xFF24100F);

  static const amberSoft = Color(0xFFFFE1A8);
  static const amberInk = Color(0xFF4A2C00);
  static const amberIconBg = Color(0xFFFFF0D6);
  static const amberIcon = Color(0xFF9A5B00);
  static const orange = Color(0xFFFFB547);

  static const blueSoft = Color(0xFFD6E6FF);
  static const blueInk = Color(0xFF12305E);
  static const blueBg = Color(0xFFEAF2FF);
  static const blue = Color(0xFF2E6DE0);

  static const purpleSoft = Color(0xFFE8D5FF);
  static const purpleInk = Color(0xFF3D1A66);
  static const purple = Color(0xFF9B6BDB);

  static const redSoft = Color(0xFFFFE0E0);
  static const redInk = Color(0xFFB3261E);
  static const redDark = Color(0xFF8C1D18);
  static const red = Color(0xFFE04848);

  static const green = Color(0xFF2DBE60);
  static const mapBg = Color(0xFFDDE3D4);
  static const mapGrid = Color(0xFFCFD7C5);

  static Color white(double o) => Colors.white.withValues(alpha: o);

  static const forestGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.3,
    colors: [forestLight, forest, forestDeep],
    stops: [0, .55, 1],
  );

  static const maroonGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [maroonMid, maroon, maroonDeep],
    stops: [0, .6, 1],
  );
}
