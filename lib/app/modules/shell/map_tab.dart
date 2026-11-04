import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/map_canvas.dart';
import 'shell.dart';

/// 13 · Carte des parcelles
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  static const _view = Size(324, 704);
  static const _plots = [
    PlotShape(
        [Offset(30, 200), Offset(120, 180), Offset(135, 260), Offset(45, 282)],
        fill: Color(0x730F3D2A), stroke: AppColors.forest),
    PlotShape([
      Offset(160, 215),
      Offset(260, 205),
      Offset(270, 300),
      Offset(172, 312)
    ], fill: Color(0x730F3D2A), stroke: AppColors.forest),
    PlotShape(
        [Offset(50, 340), Offset(150, 328), Offset(160, 415), Offset(62, 432)],
        fill: Color(0x592E6DE0), stroke: AppColors.blue),
    PlotShape([
      Offset(182, 350),
      Offset(275, 340),
      Offset(285, 435),
      Offset(192, 445)
    ], fill: Color(0x4DFF6B6B), stroke: AppColors.red, dashed: true),
    PlotShape(
        [Offset(80, 470), Offset(210, 480), Offset(200, 545), Offset(70, 535)],
        fill: Color(0x730F3D2A), stroke: AppColors.forest),
  ];

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    final bottom = ShellView.bottomInset(context);
    return StatusBarStyle(
      dark: false,
      child: Stack(children: [
        const MapGridBackground(),
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 3,
            child: const AnimatedPlots(
                shapes: _plots,
                viewBox: _view,
                duration: Duration(milliseconds: 1600)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FadeSlideIn(
                offset: const Offset(0, -40),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 8))
                    ],
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text('Carte',
                            style: jakarta(20,
                                weight: FontWeight.w800,
                                color: Colors.white,
                                tracking: -.02))),
                    Obx(() => s.toFix.isEmpty
                        ? const SizedBox.shrink()
                        : Chip2(
                            label: '${s.toFix.length} à corriger',
                            icon: Symbols.error_rounded,
                            onTap: () => Get.toNamed(Routes.sync))),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (i, c) in [
                  const Chip2(
                      label: 'Hors ligne',
                      icon: Symbols.offline_pin_rounded,
                      bg: AppColors.lime,
                      fg: AppColors.forest,
                      size: 10),
                  const Chip2(
                      label: 'Validée',
                      dot: _Swatch(AppColors.forest),
                      bg: Colors.white,
                      fg: AppColors.ink,
                      size: 10),
                  const Chip2(
                      label: 'Relevée',
                      dot: _Swatch(AppColors.blue),
                      bg: Colors.white,
                      fg: AppColors.ink,
                      size: 10),
                  const Chip2(
                      label: 'À reprendre',
                      dot: _Swatch(AppColors.red),
                      bg: Colors.white,
                      fg: AppColors.ink,
                      size: 10),
                ].indexed)
                  FadeSlideIn(
                      delay: Motion.stagger(i, base: 150),
                      scale: .6,
                      offset: const Offset(0, -10),
                      child: c),
              ]),
            ]),
          ),
        ),
        Positioned(
          right: 14,
          top: MediaQuery.paddingOf(context).top + 150,
          child: Column(children: [
            for (final (i, icon) in const [
              Symbols.my_location_rounded,
              Symbols.layers_rounded
            ].indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              FadeSlideIn(
                delay: Motion.stagger(i, base: 400),
                offset: const Offset(40, 0),
                child: Pressable(
                  onTap: () => showToast(
                      i == 0
                          ? 'Position GPS : ± 3 m'
                          : 'Fond de carte : satellite (hors ligne)',
                      icon: icon),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 12,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Icon(icon, size: 22),
                  ),
                ),
              ),
            ],
          ]),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: bottom,
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 500),
            offset: const Offset(0, 60),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.forest.withValues(alpha: .35),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: SwipeCta(
                label: 'Glissez pour relever une parcelle',
                icon: Symbols.location_on_rounded,
                // La page s'empile par-dessus : on ne l'attend pas, la poignée repart une fois recouverte.
                onConfirm: () {
                  Get.toNamed(Routes.survey);
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: 9,
      height: 9,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));
}
