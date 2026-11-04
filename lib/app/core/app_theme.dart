import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forest,
        primary: AppColors.forest,
        secondary: AppColors.lime,
        surface: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'PlusJakartaSans',
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.forest,
        selectionColor: Color(0x55C6F05A),
        selectionHandleColor: AppColors.forest,
      ),
    );
  }
}

/// Durées et courbes partagées : l'ensemble est volontairement très expressif.
abstract final class Motion {
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 700);
  static const page = Duration(milliseconds: 520);

  static const spring = Curves.easeOutBack;
  static const smooth = Curves.easeOutCubic;
  static const emphasized = Cubic(.2, 0, 0, 1);

  /// Délai d'apparition d'un élément de liste en cascade.
  static Duration stagger(int i, {int step = 60, int base = 80}) =>
      Duration(milliseconds: base + i * step);
}
