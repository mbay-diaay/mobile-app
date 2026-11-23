import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// 23 · Espace producteur — aperçu dense de ce que voit le producteur connecté.
class ProducerSpaceView extends StatelessWidget {
  const ProducerSpaceView({super.key});

  static const _plots = [
    (
      code: 'PA-0006',
      ha: '0,43 ha',
      crops: 'Carotte, Aubergine',
      status: 'Relevée',
      statusBg: AppColors.blueSoft,
      statusFg: AppColors.blueInk,
      village: 'Mboro'
    ),
    (
      code: 'PA-0012',
      ha: '0,28 ha',
      crops: 'Oignon',
      status: 'Cultures OK',
      statusBg: AppColors.sage,
      statusFg: AppColors.forest,
      village: 'Mboro'
    ),
    (
      code: 'PA-0018',
      ha: '0,15 ha',
      crops: 'Chou',
      status: 'À compléter',
      statusBg: AppColors.amberIconBg,
      statusFg: AppColors.amberInk,
      village: 'Kayar'
    ),
  ];

  static const _alerts = [
    (
      icon: Symbols.water_drop_rounded,
      title: 'Irrigation · PA-0006',
      sub: 'Prochain passage recommandé cette semaine',
      tint: AppColors.blueSoft,
      ink: AppColors.blueInk,
    ),
    (
      icon: Symbols.agriculture_rounded,
      title: 'Récolte oignon approche',
      sub: 'Fenêtre estimée : début décembre',
      tint: AppColors.lime,
      ink: AppColors.forest,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget item(Widget w) =>
        FadeSlideIn(delay: Motion.stagger(i++, base: 80, step: 55), child: w);
    final producer = MockData.producers[8];

    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Column(children: [
          DarkHeader(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item(Row(children: [
                  SquareIconButton.onDark(onTap: Get.back),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Espace producteur',
                        style: display(22, color: Colors.white)),
                  ),
                ])),
                const SizedBox(height: 12),
                item(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Sym(Symbols.visibility_rounded,
                        size: 18, color: AppColors.lime),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aperçu · ce que voit le producteur connecté',
                        style: jakarta(12,
                            weight: FontWeight.w600,
                            color: AppColors.white(.85)),
                      ),
                    ),
                  ]),
                )),
                const SizedBox(height: 14),
                item(Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text('MK',
                        style: jakarta(18,
                            weight: FontWeight.w800, color: AppColors.forest)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenue',
                            style:
                                jakarta(12, color: AppColors.white(.65))),
                        Text('Mamadou Kane',
                            style: jakarta(22,
                                weight: FontWeight.w800,
                                color: Colors.white,
                                tracking: -.02)),
                        Text('Mboro · Membre · SCOOP Démo Niayes',
                            style:
                                jakarta(12, color: AppColors.white(.7))),
                      ],
                    ),
                  ),
                ])),
              ],
            ),
          ),
          Expanded(
            child: FillScroll(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  item(Row(children: [
                    _Kpi(
                      label: 'Parcelles',
                      value: '${_plots.length}',
                      icon: Symbols.pentagon_rounded,
                    ),
                    const SizedBox(width: 8),
                    const _Kpi(
                      label: 'Surface',
                      value: '0,86 ha',
                      icon: Symbols.square_foot_rounded,
                    ),
                    const SizedBox(width: 8),
                    const _Kpi(
                      label: 'Campagne',
                      value: '25-26',
                      icon: Symbols.calendar_month_rounded,
                      small: true,
                    ),
                  ])),
                  const SizedBox(height: 18),
                  item(Row(children: [
                    Text('Mes parcelles',
                        style: jakarta(16, weight: FontWeight.w800)),
                    const Spacer(),
                    Text('${_plots.length} fiches',
                        style: jakarta(12, color: AppColors.muted)),
                  ])),
                  const SizedBox(height: 10),
                  for (final (j, p) in _plots.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: j < _plots.length - 1 ? 8 : 0),
                      child: item(_PlotCard(
                        code: p.code,
                        ha: p.ha,
                        crops: p.crops,
                        village: p.village,
                        status: p.status,
                        statusBg: p.statusBg,
                        statusFg: p.statusFg,
                      )),
                    ),
                  const SizedBox(height: 18),
                  item(Row(children: [
                    Expanded(
                      child: Text('À surveiller',
                          style: jakarta(16, weight: FontWeight.w800)),
                    ),
                    Text('2 alertes',
                        style: jakarta(12,
                            weight: FontWeight.w700, color: AppColors.forest)),
                  ])),
                  const SizedBox(height: 10),
                  for (final (j, a) in _alerts.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: j < _alerts.length - 1 ? 8 : 0),
                      child: item(_AlertCard(
                        icon: a.icon,
                        title: a.title,
                        sub: a.sub,
                        tint: a.tint,
                        ink: a.ink,
                      )),
                    ),
                  const SizedBox(height: 18),
                  item(Pressable(
                    onTap: () => Get.toNamed(Routes.cropCalendar, arguments: {
                      'crop': 'Oignon',
                      'plot': 'PA-0012',
                    }),
                    child: Row(children: [
                      Expanded(
                        child: Text('Calendrier · Oignon',
                            style: jakarta(16, weight: FontWeight.w800)),
                      ),
                      Text('Voir',
                          style: jakarta(12,
                              weight: FontWeight.w700,
                              color: AppColors.forest)),
                      const Sym(Symbols.chevron_right_rounded,
                          size: 20, color: AppColors.forest),
                    ]),
                  )),
                  const SizedBox(height: 10),
                  item(const _Calendar()),
                  const SizedBox(height: 18),
                  item(Text('Prochaines actions',
                      style: jakarta(16, weight: FontWeight.w800))),
                  const SizedBox(height: 10),
                  item(const _ActionHint(
                    icon: Symbols.checklist_rounded,
                    title: 'Compléter les cultures · PA-0018',
                    sub: 'Le technicien a relevé la parcelle — déclarez les cultures.',
                  )),
                  const SizedBox(height: 8),
                  item(const _ActionHint(
                    icon: Symbols.forum_rounded,
                    title: 'Réunion SCOOP · 28 nov.',
                    sub: 'Assemblée ordinaire à Mboro — présence souhaitée.',
                  )),
                  const SizedBox(height: 20),
                  item(SwipeCta.dark(
                    label: 'Glissez pour demander une correction',
                    onConfirm: () async => Get.toNamed(Routes.correctionRequest,
                        arguments: producer),
                  )),
                  const SizedBox(height: 10),
                  item(Text(
                    'Toute correction est transmise à votre technicien / SCOOP.',
                    textAlign: TextAlign.center,
                    style: jakarta(11, color: AppColors.muted, height: 1.35),
                  )),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.small = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool small;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sym(icon, size: 18, color: AppColors.forest),
              const SizedBox(height: 8),
              Text(value,
                  style: jakarta(small ? 16 : 22,
                      weight: FontWeight.w800,
                      color: AppColors.forest,
                      tracking: -.02)),
              const SizedBox(height: 2),
              Text(label, style: jakarta(11, color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _PlotCard extends StatelessWidget {
  const _PlotCard({
    required this.code,
    required this.ha,
    required this.crops,
    required this.village,
    required this.status,
    required this.statusBg,
    required this.statusFg,
  });
  final String code;
  final String ha;
  final String crops;
  final String village;
  final String status;
  final Color statusBg;
  final Color statusFg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(children: [
          const IconTile(Symbols.pentagon_rounded,
              size: 44, radius: 14, bg: AppColors.sage, fill: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$code · $ha',
                    style: jakarta(14, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('$crops · $village',
                    style: jakarta(12, color: AppColors.muted)),
              ],
            ),
          ),
          Chip2(
            label: status,
            bg: statusBg,
            fg: statusFg,
            size: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ]),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.tint,
    required this.ink,
  });
  final IconData icon;
  final String title;
  final String sub;
  final Color tint;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Sym(icon, size: 22, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: jakarta(13, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, style: jakarta(12, color: AppColors.muted)),
              ],
            ),
          ),
        ]),
      );
}

class _ActionHint extends StatelessWidget {
  const _ActionHint({
    required this.icon,
    required this.title,
    required this.sub,
  });
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sage,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Sym(icon, size: 22, color: AppColors.forest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: jakarta(13, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub,
                    style: jakarta(12, color: AppColors.muted, height: 1.35)),
              ],
            ),
          ),
        ]),
      );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Campagne 2025-2026',
              style: jakarta(12, weight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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
