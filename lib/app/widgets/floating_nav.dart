import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'animations.dart';

/// Barre de navigation flottante sombre ; la pastille citron glisse vers l'onglet actif.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar(
      {super.key, required this.index, required this.onTap, this.badge = 8});

  final int index;
  final ValueChanged<int> onTap;
  final int badge;

  static const icons = [
    Symbols.home_rounded,
    Symbols.groups_rounded,
    Symbols.map_rounded,
    Symbols.checklist_rounded,
    Symbols.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      offset: const Offset(0, 90),
      delay: const Duration(milliseconds: 250),
      duration: const Duration(milliseconds: 900),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))
          ],
        ),
        child: LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth / icons.length;
          return Stack(alignment: Alignment.centerLeft, children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 520),
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
              for (var i = 0; i < icons.length; i++)
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
                              curve: Curves.elasticOut,
                              child: TweenAnimationBuilder<Color?>(
                                tween: ColorTween(
                                    end: i == index
                                        ? AppColors.forest
                                        : AppColors.white(.65)),
                                duration: Motion.fast,
                                builder: (_, col, __) => Icon(icons[i],
                                    size: 22,
                                    color: col,
                                    fill: i == index ? 1 : 0),
                              ),
                            ),
                            if (i == 3 && badge > 0)
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
