import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Polices variables embarquées : la graisse passe par l'axe `wght`.
List<FontVariation> _wght(FontWeight w) =>
    [FontVariation.weight(w.value.toDouble())];

/// Plus Jakarta Sans pour tout le texte, JetBrains Mono pour les codes.
/// `tracking` est exprimé en em, comme dans la maquette (-0.03em…).
TextStyle jakarta(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double tracking = 0,
  double? height,
  FontStyle? style,
}) =>
    TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: size,
      fontWeight: weight,
      fontVariations: _wght(weight),
      color: color,
      letterSpacing: tracking * size,
      height: height,
      fontStyle: style,
    );

TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double tracking = 0,
}) =>
    TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: size,
      fontWeight: weight,
      fontVariations: _wght(weight),
      color: color,
      letterSpacing: tracking * size,
    );

/// Gros titre très gras (« 30px / 800 / -0.03em »).
TextStyle display(double size,
        {Color color = AppColors.ink, double height = 1.05}) =>
    jakarta(size,
        weight: FontWeight.w800, color: color, tracking: -0.03, height: height);
