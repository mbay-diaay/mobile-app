import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// Calendrier cultural (MO-33) — lecture de la dernière version synchronisée.
class CropCalendarView extends StatelessWidget {
  const CropCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? {};
    final crop = args['crop'] as String? ?? 'Oignon';
    final plot = args['plot'] as String? ?? 'PA-0006';
    var i = 0;
    Widget item(Widget w) =>
        FadeSlideIn(delay: Motion.stagger(i++, base: 80, step: 60), child: w);

    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: FillScroll(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(Row(children: [
                  SquareIconButton(onTap: Get.back),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Calendrier cultural', style: display(22))),
                ])),
                const SizedBox(height: 12),
                item(Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const IconTile(Symbols.calendar_month_rounded,
                        size: 44, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(crop,
                              style: jakarta(16, weight: FontWeight.w800)),
                          Text('$plot · dernière version synchronisée',
                              style: jakarta(12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ]),
                )),
                const SizedBox(height: 14),
                item(Text('Calendrier · $crop',
                    style: jakarta(14, weight: FontWeight.w800))),
                const SizedBox(height: 10),
                item(const _YearCalendar()),
                const SizedBox(height: 16),
                item(Text(
                  'Les stades viennent du référentiel SCOOP. Hors ligne : dernière copie locale.',
                  style: jakarta(12, color: AppColors.muted, height: 1.4),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YearCalendar extends StatelessWidget {
  const _YearCalendar();

  static const _months = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D'
  ];

  static const _rows = [
    [(10, 11, AppColors.orange), (11, 13, AppColors.purple)],
    [(1, 4, AppColors.forest), (4, 6, AppColors.lime)],
  ];

  static const _legend = [
    ('Semis', AppColors.orange),
    ('Repiquage', AppColors.purple),
    ('Entretien', AppColors.forest),
    ('Récolte', AppColors.lime),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (final m in _months)
              Expanded(
                  child: Text(m,
                      textAlign: TextAlign.center,
                      style: jakarta(9,
                          weight: FontWeight.w700, color: AppColors.muted))),
          ]),
          for (final (r, row) in _rows.indexed) ...[
            const SizedBox(height: 7),
            SizedBox(
              height: 16,
              child: Row(children: [
                for (final (k, bar) in row.indexed) ...[
                  if (bar.$1 > (k == 0 ? 1 : row[k - 1].$2))
                    Spacer(flex: bar.$1 - (k == 0 ? 1 : row[k - 1].$2)),
                  Expanded(
                    flex: bar.$2 - bar.$1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            Duration(milliseconds: 700 + 200 * (r * 2 + k)),
                        curve: Motion.smooth,
                        builder: (_, t, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: bar.$3,
                                  borderRadius: BorderRadius.circular(5))),
                        ),
                      ),
                    ),
                  ),
                ],
                if (row.last.$2 < 13) Spacer(flex: 13 - row.last.$2),
              ]),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final (l, c) in _legend)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(l, style: jakarta(10, weight: FontWeight.w600)),
              ]),
          ]),
        ]),
      );
}
