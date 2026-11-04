import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/map_canvas.dart';

/// 17 · Relevé terminé (la parcelle a été enregistrée par « Terminer »).
class SurveyDoneView extends StatefulWidget {
  const SurveyDoneView({super.key});

  @override
  State<SurveyDoneView> createState() => _SurveyDoneViewState();
}

class _SurveyDoneViewState extends State<SurveyDoneView> {
  late final Map args = (Get.arguments as Map?) ?? {};
  late final List<Offset> points =
      (args['points'] as List<Offset>?) ?? MockData.surveyCorners;
  late final Producer owner =
      (args['owner'] as Producer?) ?? MockData.producers[8];
  late final String code = (args['code'] as String?) ?? 'PA-0034';
  late final double area =
      (args['area'] as double?) ?? indicativeHectares(points);
  static const declared = 0.20;

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final gap = ((area - declared) / declared * 100).round();
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: Column(children: [
          SizedBox(
            height: 250 + MediaQuery.paddingOf(context).top,
            child: Stack(children: [
              const MapGridBackground(),
              Positioned.fill(
                top: MediaQuery.paddingOf(context).top + 20,
                bottom: 20,
                child: AnimatedPlots(
                  viewBox: const Size(324, 380),
                  strokeWidth: 3,
                  shapes: [
                    PlotShape(points,
                        stroke: AppColors.forest, fill: const Color(0x800F3D2A))
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Row(children: [
                    SquareIconButton(
                        size: 38,
                        onTap: () => Get.until((r) =>
                            r.settings.name == Routes.shell || r.isFirst)),
                    const SizedBox(width: 8),
                    Chip2(
                      label: '${owner.name} · $code',
                      bg: Colors.white,
                      fg: AppColors.ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                    color: AppColors.cream,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28))),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: FillScroll(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const FadeSlideIn(
                            delay: Duration(milliseconds: 600),
                            scale: 0,
                            offset: Offset.zero,
                            curve: Curves.elasticOut,
                            duration: Duration(milliseconds: 1100),
                            child: IconTile(Symbols.check_circle_rounded,
                                size: 48, radius: 16, iconSize: 28, fill: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeSlideIn(
                              delay: const Duration(milliseconds: 650),
                              offset: const Offset(30, 0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Parcelle relevée',
                                        style: display(22)),
                                    Text(
                                        'Gardée sur le téléphone · statut « relevée »',
                                        style: jakarta(11,
                                            color: AppColors.muted)),
                                  ]),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 750),
                          scale: .9,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.forest,
                                borderRadius: BorderRadius.circular(24)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Superficie',
                                              style: jakarta(11,
                                                  color: AppColors.white(.65))),
                                          CountUp(
                                            value: area,
                                            decimals: 2,
                                            prefix: '≈ ',
                                            suffix: ' ha',
                                            duration: const Duration(
                                                milliseconds: 1500),
                                            style: jakarta(40,
                                                weight: FontWeight.w800,
                                                color: AppColors.lime,
                                                tracking: -.04,
                                                height: 1),
                                            suffixStyle: jakarta(16,
                                                weight: FontWeight.w800,
                                                color: Colors.white),
                                          ),
                                        ]),
                                  ),
                                  Sym(Symbols.square_foot_rounded,
                                      size: 28, color: AppColors.white(.3)),
                                ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: FadeSlideIn(
                              delay: const Duration(milliseconds: 850),
                              child: _Stat(
                                  label: 'Déclarée',
                                  value: '${_fmt(declared)} ha',
                                  bg: Colors.white,
                                  fg: AppColors.ink),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FadeSlideIn(
                              delay: const Duration(milliseconds: 920),
                              child: _Stat(
                                label: 'Écart',
                                value: '${gap >= 0 ? '+' : ''}$gap %',
                                bg: AppColors.amberSoft,
                                fg: AppColors.amberInk,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          "Superficie indicative. La valeur officielle sera calculée par le serveur après l'envoi.",
                          style:
                              jakarta(10, color: AppColors.muted, height: 1.45),
                        ),
                        const Spacer(),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 1000),
                          child: SwipeCta(
                            label: 'Glissez pour déclarer les cultures',
                            icon: Symbols.potted_plant_rounded,
                            height: 58,
                            onConfirm: () => Get.offNamed(Routes.crops,
                                arguments: {
                                  'code': code,
                                  'owner': owner,
                                  'area': area
                                }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () => Get.until((r) =>
                                r.settings.name == Routes.shell || r.isFirst),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text('Plus tard',
                                  style: jakarta(14,
                                      weight: FontWeight.w700,
                                      color: AppColors.forest)),
                            ),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.bg,
      required this.fg});
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: jakarta(11,
                  color: fg == AppColors.ink ? AppColors.muted : fg)),
          Text(value, style: jakarta(20, weight: FontWeight.w800, color: fg)),
        ]),
      );
}
