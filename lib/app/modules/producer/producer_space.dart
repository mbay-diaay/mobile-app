import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// 23 · Espace producteur (aperçu de ce que voit le producteur connecté).
class ProducerSpaceView extends StatelessWidget {
  const ProducerSpaceView({super.key});

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget item(Widget w) =>
        FadeSlideIn(delay: Motion.stagger(i++, base: 100, step: 70), child: w);

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
                    Text('Espace producteur', style: display(20)),
                  ])),
                  const SizedBox(height: 10),
                  item(Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Sym(Symbols.visibility_rounded,
                          size: 18, color: AppColors.blueInk),
                      const SizedBox(width: 8),
                      Text('Aperçu de ce que voit le producteur connecté.',
                          style: jakarta(11,
                              weight: FontWeight.w600,
                              color: AppColors.blueInk)),
                    ]),
                  )),
                  const SizedBox(height: 10),
                  item(Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(24)),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(18)),
                        alignment: Alignment.center,
                        child: Text('MK',
                            style: jakarta(17,
                                weight: FontWeight.w800,
                                color: AppColors.forest)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bienvenue',
                                style: jakarta(11, color: AppColors.white(.6))),
                            Text('Mamadou Kane',
                                style: jakarta(20,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                    tracking: -.02)),
                            Text('Mboro · Membre',
                                style: jakarta(11, color: AppColors.white(.7))),
                          ]),
                    ]),
                  )),
                  const SizedBox(height: 10),
                  item(Text('Mes parcelles',
                      style: jakarta(14, weight: FontWeight.w800))),
                  const SizedBox(height: 10),
                  item(Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const IconTile(Symbols.pentagon_rounded,
                          size: 40, radius: 13, bg: AppColors.sage),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PA-0006 · 0,43 ha',
                                  style: jakarta(13, weight: FontWeight.w800)),
                              Text('Carotte, Aubergine',
                                  style: jakarta(11, color: AppColors.muted)),
                            ]),
                      ),
                      const Chip2(
                        label: 'Relevée',
                        bg: AppColors.blueSoft,
                        fg: AppColors.blueInk,
                        size: 10,
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 10),
                  item(Text('Calendrier · Oignon',
                      style: jakarta(14, weight: FontWeight.w800))),
                  const SizedBox(height: 10),
                  item(const _Calendar()),
                  const Spacer(),
                  const SizedBox(height: 10),
                  item(FlatButton(
                    label: 'Demander une correction',
                    icon: Symbols.edit_note_rounded,
                    height: 54,
                    weight: FontWeight.w800,
                    onTap: () => showToast('Demande envoyée au technicien.',
                        icon: Symbols.edit_note_rounded),
                  )),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Frise de 12 mois ; les barres s'étirent depuis leur mois de départ.
class _Calendar extends StatelessWidget {
  const _Calendar();

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

  // (début, fin exclue, couleur) en mois 1-12, comme les grid-column de la maquette.
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
                  // Espace vide jusqu'au mois de départ de la barre.
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
