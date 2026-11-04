import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../routes/app_routes.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// Une ligne du récapitulatif (une culture, par exemple).
class SuccessRow {
  const SuccessRow({
    required this.short,
    required this.title,
    required this.tint,
    required this.ink,
    this.subtitle = '',
    this.trailing = '',
    this.caption = '',
    this.progress,
  });
  final String short;
  final String title;
  final String subtitle;
  final Color tint;
  final Color ink;
  final String trailing;
  final String caption;
  final double? progress;
}

/// Un groupe de lignes sous un titre (une saison, par exemple).
class SuccessGroup {
  const SuccessGroup(this.title, this.rows);
  final String title;
  final List<SuccessRow> rows;
}

/// Écran de réussite générique (ajouté) : fiche, cultures, correction.
/// Arguments : {title, sub, cta, route?, groups?}. Arrive de la droite et se valide en glissant :
/// sans `route`, on revient à l'accueil ; avec `route`, on enchaîne sur l'étape suivante
/// (et un second bouton ramène à l'accueil). Avec `groups`, un récapitulatif défile sous le titre.
class SuccessView extends StatelessWidget {
  const SuccessView({super.key});

  static void backHome() =>
      Get.until((r) => r.settings.name == Routes.shell || r.isFirst);

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? {};
    final title = args['title'] as String? ?? 'C\'est fait !';
    final sub = args['sub'] as String? ?? '';
    final cta = args['cta'] as String? ?? "Retour à l'accueil";
    final route = args['route'] as String?;
    final groups = (args['groups'] as List?)?.cast<SuccessGroup>() ??
        const <SuccessGroup>[];
    // Liste à plat (en-têtes + lignes) pour un défilement paresseux, même avec des centaines de lignes.
    final items = <Object>[
      for (final g in groups) ...[g, ...g.rows],
    ];
    final compact = items.isNotEmpty;

    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.forestGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (compact) const SizedBox(height: 4) else const Spacer(),
                SizedBox(
                  width: compact ? 130 : 220,
                  height: compact ? 130 : 220,
                  child: const FittedBox(
                      child:
                          SizedBox(width: 220, height: 220, child: _Burst())),
                ),
                SizedBox(height: compact ? 0 : 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: display(compact ? 26 : 30,
                          color: Colors.white, height: 1.1)),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: Text(sub,
                      textAlign: TextAlign.center,
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: jakarta(compact ? 13 : 14,
                          color: AppColors.white(.72), height: 1.5)),
                ),
                if (compact) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 700),
                      offset: const Offset(0, 30),
                      child: _ResultList(items: items),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const Spacer(),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 750),
                  child: SwipeCta(
                    label: route == null
                        ? "Glissez pour revenir à l'accueil"
                        : 'Glissez : ${cta[0].toLowerCase()}${cta.substring(1)}',
                    onConfirm: () => route == null
                        ? backHome()
                        : Get.offNamed(route, arguments: args['args']),
                  ),
                ),
                if (route != null) ...[
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 820),
                    child: FlatButton(
                      label: "Retour à l'accueil",
                      bg: Colors.transparent,
                      fg: Colors.white,
                      border: AppColors.white(.3),
                      onTap: backHome,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Récapitulatif défilant. `ListView.builder` ne construit que les lignes visibles,
/// et les lignes n'ont aucune animation propre : le défilement reste fluide à 100+ lignes.
class _ResultList extends StatelessWidget {
  const _ResultList({required this.items});
  final List<Object> items;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: AppColors.white(.07),
            borderRadius: BorderRadius.circular(26)),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return it is SuccessGroup
                ? _GroupHeader(group: it)
                : _RowTile(row: it as SuccessRow);
          },
        ),
      );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final SuccessGroup group;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Row(children: [
          Expanded(
            child: Text(group.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(10,
                    weight: FontWeight.w700, color: AppColors.white(.7))),
          ),
          Text('${group.rows.length}',
              style: mono(10, weight: FontWeight.w700, color: AppColors.lime)),
        ]),
      );
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});
  final SuccessRow row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.white(.08),
            borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: row.tint, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text(row.short,
                  style: jakarta(13, weight: FontWeight.w800, color: row.ink)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(15,
                            weight: FontWeight.w800, color: Colors.white)),
                    if (row.subtitle.isNotEmpty)
                      Text(row.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: jakarta(11.5, color: AppColors.white(.6))),
                  ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (row.trailing.isNotEmpty)
                Text(row.trailing,
                    style: jakarta(16,
                        weight: FontWeight.w800, color: AppColors.lime)),
              if (row.caption.isNotEmpty)
                Text(row.caption, style: mono(10, color: AppColors.white(.6))),
            ]),
          ]),
          if (row.progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: row.progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.white(.12),
                valueColor: const AlwaysStoppedAnimation(AppColors.lime),
              ),
            ),
          ],
        ]),
      );
}

/// Coche qui rebondit, entourée d'éclats citron qui jaillissent.
class _Burst extends StatefulWidget {
  const _Burst();

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Stack(alignment: Alignment.center, children: [
            for (var i = 0; i < 12; i++)
              Transform.translate(
                offset: Offset.fromDirection(i * math.pi / 6, 40 + 70 * t),
                child: Opacity(
                  opacity: (1 - t).clamp(0, 1),
                  child: Container(
                    width: i.isEven ? 10 : 6,
                    height: i.isEven ? 10 : 6,
                    decoration: BoxDecoration(
                      color: i % 3 == 0 ? AppColors.orange : AppColors.lime,
                      borderRadius: BorderRadius.circular(i.isEven ? 3 : 6),
                    ),
                  ),
                ),
              ),
            Container(
              width: 120 + 30 * t,
              height: 120 + 30 * t,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime.withValues(alpha: .12 * (1 - t) + .04)),
            ),
            Transform.scale(
              scale: Curves.elasticOut.transform(_c.value),
              child: const IconTile(Symbols.check_rounded,
                  size: 96, radius: 32, iconSize: 54),
            ),
          ]);
        },
      );
}
