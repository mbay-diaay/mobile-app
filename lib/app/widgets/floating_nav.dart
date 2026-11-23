import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'animations.dart';

/// Barre de navigation flottante sombre ; la pastille citron glisse vers l'onglet actif.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.index,
    required this.onTap,
    this.badge = 8,
    this.icons = technicianIcons,
    this.badgeIndex = 3,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int badge;

  /// Icônes (technicien par défaut ; producteur passe sa liste).
  final List<IconData> icons;

  /// Onglet qui porte le badge (−1 = aucun).
  final int badgeIndex;

  static const technicianIcons = [
    Symbols.home_rounded,
    Symbols.groups_rounded,
    Symbols.map_rounded,
    Symbols.checklist_rounded,
    Symbols.person_rounded,
  ];

  static const producerIcons = [
    Symbols.home_rounded,
    Symbols.pentagon_rounded,
    Symbols.calendar_month_rounded,
    Symbols.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final list = icons;
    return FadeSlideIn(
      offset: const Offset(0, 90),
      delay: Motion.stagger(2, base: 180, step: 40),
      duration: Motion.slow,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ],
        ),
        child: LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth / list.length;
          return Stack(alignment: Alignment.centerLeft, children: [
            AnimatedPositioned(
              duration: Motion.medium,
              curve: Motion.spring,
              left: w * index + (w - 52) / 2,
              width: 52,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            Row(children: [
              for (var i = 0; i < list.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 64,
                      child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: i == index ? 1.12 : 1,
                              duration: Motion.medium,
                              curve: Motion.spring,
                              child: TweenAnimationBuilder<Color?>(
                                tween: ColorTween(
                                    end: i == index
                                        ? AppColors.forest
                                        : AppColors.white(.65)),
                                duration: Motion.fast,
                                builder: (_, col, __) => Icon(list[i],
                                    size: 22,
                                    color: col,
                                    fill: i == index ? 1 : 0),
                              ),
                            ),
                            if (i == badgeIndex && badge > 0)
                              Positioned(
                                top: 12,
                                left: w / 2 + 8,
                                child: Breathing(
                                  amount: .12,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 16),
                                    height: 16,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                        color: AppColors.coral,
                                        borderRadius: BorderRadius.circular(8)),
                                    alignment: Alignment.center,
                                    child: Text('$badge',
                                        style: jakarta(9,
                                            weight: FontWeight.w800,
                                            color: AppColors.maroon)),
                                  ),
                                ),
                              ),
                          ]),
                    ),
                  ),
                ),
            ]),
          ]);
        }),
      ),
    );
  }
}
