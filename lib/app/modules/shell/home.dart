import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart' show Producer;
import '../../routes/app_routes.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import 'producers.dart' show ProducerRow;
import 'shell.dart';

/// Accueil : variante A (07, hors ligne) ou B (08, en ligne) selon le réseau.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final net = Get.find<NetworkService>();
    return Obx(() => AnimatedSwitcher(
          duration: Motion.slow,
          switchInCurve: Motion.smooth,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
                scale: Tween(begin: .96, end: 1.0).animate(a), child: c),
          ),
          child: net.online.value
              ? const _HomeOnline(key: ValueKey('on'))
              : const _HomeOffline(key: ValueKey('off')),
        ));
  }
}

String _frenchDate(DateTime d) {
  const days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche'
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre'
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

void _goTab(int i) => Get.find<ShellController>().go(i);

// ───────────────────────────── 07 · Accueil A · hors ligne

class _HomeOffline extends StatelessWidget {
  const _HomeOffline({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    return Column(children: [
      DarkHeader(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(children: [
          Row(children: [
            const _Avatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour',
                        style: jakarta(11, color: AppColors.white(.6))),
                    Text(s.technician,
                        style: jakarta(16,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            tracking: -.02)),
                  ]),
            ),
            Chip2(
              label: 'Hors ligne',
              bg: AppColors.white(.1),
              fg: Colors.white,
              dot: const PulseDot(color: AppColors.orange, size: 7),
              padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
              onTap: Get.find<NetworkService>().toggle,
            ),
          ]),
          const SizedBox(height: 16),
          Obx(() => s.toFix.isEmpty
              ? const SizedBox.shrink()
              : FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  scale: .9,
                  child: Pressable(
                    onTap: () => Get.toNamed(Routes.sync),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        Breathing(
                          amount: .08,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: AppColors.maroon,
                                borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.center,
                            child: Text('${s.toFix.length}',
                                style: jakarta(21,
                                    weight: FontWeight.w800,
                                    color: AppColors.coral)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('éléments à corriger',
                                    style: jakarta(16,
                                        weight: FontWeight.w800,
                                        color: AppColors.maroon)),
                                const SizedBox(height: 2),
                                Text('Touchez pour voir et corriger.',
                                    style:
                                        jakarta(12.5, color: AppColors.maroon)),
                              ]),
                        ),
                        const NudgeX(
                            child: Sym(Symbols.arrow_forward_rounded,
                                color: AppColors.maroon)),
                      ]),
                    ),
                  ),
                )),
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(16, 16, 16, ShellView.bottomInset(context)),
          children: [
            Row(children: [
              Expanded(
                child: FadeSlideIn(
                  delay: Motion.stagger(0, base: 200),
                  offset: const Offset(-30, 30),
                  child: const _BigTile(
                    icon: Symbols.person_add_rounded,
                    title: 'Nouveau producteur',
                    height: 172,
                    variant: _TileVariant.lime,
                    route: Routes.newProducer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FadeSlideIn(
                  delay: Motion.stagger(1, base: 200),
                  offset: const Offset(30, 30),
                  child: const _BigTile(
                    icon: Symbols.location_on_rounded,
                    title: 'Relever une parcelle',
                    height: 172,
                    variant: _TileVariant.forest,
                    route: Routes.survey,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FadeSlideIn(
                  delay: Motion.stagger(2, base: 200),
                  child: _SmallCard(
                    icon: Symbols.checklist_rounded,
                    bg: AppColors.amberIconBg,
                    fg: AppColors.amberIcon,
                    title: 'À faire',
                    sub: '${s.todoCount.value} fiches',
                    onTap: () => _goTab(3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FadeSlideIn(
                  delay: Motion.stagger(3, base: 200),
                  child: _SmallCard(
                    icon: Symbols.search_rounded,
                    bg: AppColors.sage,
                    fg: AppColors.forest,
                    title: 'Chercher',
                    sub: 'un producteur',
                    onTap: () => _goTab(1),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: Motion.stagger(4, base: 200),
              child: Row(children: [
                Expanded(
                    child: Text('Vus récemment',
                        style: jakarta(16,
                            weight: FontWeight.w800, tracking: -.01))),
                GestureDetector(
                  onTap: () => _goTab(1),
                  child: Text('Tout voir',
                      style: jakarta(12,
                          weight: FontWeight.w700, color: AppColors.forest)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            // Hauteur commune : un nom sur deux lignes ne décale pas les cartes voisines.
            Obx(() => IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < s.recent.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: FadeSlideIn(
                              key: ValueKey(s.recent[i].code),
                              delay: Motion.stagger(5 + i, base: 200),
                              scale: .8,
                              child: _RecentCard(p: s.recent[i]),
                            ),
                          ),
                        ],
                      ]),
                )),
          ],
        ),
      ),
    ]);
  }
}

// ───────────────────────────── 08 · Accueil B · en ligne

class _HomeOnline extends StatelessWidget {
  const _HomeOnline({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    return Column(children: [
      DarkHeader(
        child: Column(children: [
          Row(children: [
            const _Avatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour ${s.technician}',
                        style: jakarta(16,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            tracking: -.02)),
                    Text('${_frenchDate(DateTime.now())} · ${s.scoop}',
                        style: jakarta(11, color: AppColors.white(.6))),
                  ]),
            ),
            GestureDetector(
              onTap: Get.find<NetworkService>().toggle,
              child: const PulseDot(color: AppColors.green, size: 8),
            ),
          ]),
          const SizedBox(height: 14),
          // Hauteur commune : un libellé sur deux lignes ne décale pas les compteurs voisins.
          Obx(() => IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stat(
                          value: s.createdToday.value,
                          label: 'fiche créée',
                          i: 0),
                      const SizedBox(width: 6),
                      _Stat(
                          value: s.surveyedToday.value,
                          label: 'parcelle relevée',
                          i: 1),
                      const SizedBox(width: 6),
                      _Stat(
                          value: s.cropsToday.value,
                          label: 'culture déclarée',
                          i: 2),
                    ]),
              )),
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(16, 14, 16, ShellView.bottomInset(context)),
          children: [
            GridView(
              shrinkWrap: true,
              // Sans padding explicite, la grille ajouterait les marges système (encoche, barre du bas).
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              // Hauteur fixe : tuiles compactes quelle que soit la largeur, titre sur deux lignes compris.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 160,
              ),
              children: [
                for (final (i, t) in const [
                  _BigTile(
                      icon: Symbols.groups_rounded,
                      title: 'Liste des producteurs',
                      variant: _TileVariant.lime,
                      tab: 1),
                  _BigTile(
                      icon: Symbols.location_on_rounded,
                      title: 'Relever une parcelle',
                      variant: _TileVariant.forest,
                      route: Routes.survey),
                  _BigTile(
                      icon: Symbols.person_add_rounded,
                      title: 'Nouveau producteur',
                      variant: _TileVariant.white,
                      route: Routes.newProducer),
                  _BigTile(
                      icon: Symbols.checklist_rounded,
                      title: 'Liste des tâches à effectuer',
                      variant: _TileVariant.amber,
                      tab: 3,
                      badge: true),
                ].indexed)
                  FadeSlideIn(
                      delay: Motion.stagger(i, base: 220, step: 70),
                      scale: .85,
                      child: t),
              ],
            ),
            const SizedBox(height: 14),
            Obx(() => s.pending.isEmpty
                ? const SizedBox.shrink()
                : FadeSlideIn(
                    delay: const Duration(milliseconds: 550),
                    child: Pressable(
                      onTap: () => Get.toNamed(Routes.sync),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(24)),
                        child: Row(children: [
                          const Spin(
                            period: Duration(milliseconds: 3000),
                            child: IconTile(Symbols.cloud_sync_rounded,
                                size: 48,
                                radius: 16,
                                bg: AppColors.amberInk,
                                fg: AppColors.amberSoft,
                                iconSize: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "${s.pending.length} éléments en attente d'envoi",
                                      style: jakarta(15,
                                          weight: FontWeight.w800,
                                          color: AppColors.amberInk)),
                                  const SizedBox(height: 2),
                                  Text('Envoi automatique en cours de route.',
                                      style: jakarta(12.5,
                                          color: AppColors.amberInk)),
                                ]),
                          ),
                          const NudgeX(
                              child: Sym(Symbols.arrow_forward_rounded,
                                  size: 24, color: AppColors.amberInk)),
                        ]),
                      ),
                    ),
                  )),
            const SizedBox(height: 18),
            const _History(),
          ],
        ),
      ),
    ]);
  }
}

/// Historique des producteurs enregistrés, groupé par jour, du plus récent au
/// plus ancien. Une fiche créée pendant la session arrive en tête du jour.
class _History extends StatelessWidget {
  const _History();

  static const _max = 8;

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    final s = _frenchDate(d);
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    return Obx(() {
      final list = s.activeProducers
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      final shown = list.take(_max);
      // Regroupement par jour, en gardant l'ordre chronologique inverse.
      final groups = <String, List<Producer>>{};
      for (final p in shown) {
        groups.putIfAbsent(_dayLabel(p.registeredAt), () => []).add(p);
      }
      var i = 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FadeSlideIn(
          delay: const Duration(milliseconds: 600),
          child: Row(children: [
            Text('Producteurs enregistrés',
                style: jakarta(16, weight: FontWeight.w800, tracking: -.01)),
            const SizedBox(width: 8),
            Chip2(
              label: '${s.activeProducers.length}',
              bg: AppColors.sage,
              fg: AppColors.forest,
              size: 11,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _goTab(1),
              child: Text('Tout voir',
                  style: jakarta(13,
                      weight: FontWeight.w700, color: AppColors.forest)),
            ),
          ]),
        ),
        for (final MapEntry(key: day, value: items) in groups.entries) ...[
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: Motion.stagger(i, step: 50, base: 650),
            child: Row(children: [
              Text(day.toUpperCase(),
                  style: mono(10,
                      weight: FontWeight.w700, color: AppColors.muted)),
              const SizedBox(width: 8),
              Text('· ${items.length}',
                  style: mono(10, color: AppColors.faint)),
              const SizedBox(width: 8),
              const Expanded(
                  child: Divider(
                      color: AppColors.divider, height: 1, thickness: 1)),
            ]),
          ),
          const SizedBox(height: 8),
          for (final (j, p) in items.indexed) ...[
            if (j > 0) const SizedBox(height: 8),
            FadeSlideIn(
              key: ValueKey(p.code),
              delay: Motion.stagger(++i, step: 50, base: 650),
              offset: const Offset(40, 0),
              child: ProducerRow(
                p: p,
                trailing: Text(_time(p.registeredAt),
                    style: mono(12,
                        weight: FontWeight.w600, color: AppColors.muted)),
              ),
            ),
          ],
        ],
      ]);
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.i});
  final int value;
  final String label;
  final int i;

  @override
  Widget build(BuildContext context) => Expanded(
        child: FadeSlideIn(
          delay: Motion.stagger(i, base: 250, step: 90),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.white(.08),
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CountUp(
                value: value.toDouble(),
                style: jakarta(30,
                    weight: FontWeight.w800,
                    color: value > 0 ? AppColors.lime : AppColors.white(.4),
                    height: 1),
              ),
              const SizedBox(height: 6),
              Text(label, style: jakarta(11.5, color: AppColors.white(.75))),
            ]),
          ),
        ),
      );
}

// ───────────────────────────── briques partagées

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => _goTab(4),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.lime, borderRadius: BorderRadius.circular(13)),
          alignment: Alignment.center,
          child: Text('MD',
              style: jakarta(13,
                  weight: FontWeight.w800, color: AppColors.forest)),
        ),
      );
}

enum _TileVariant { lime, forest, white, amber }

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.title,
    required this.variant,
    this.height,
    this.route,
    this.tab,
    this.badge = false,
  });

  final IconData icon;
  final String title;
  final _TileVariant variant;
  final double? height;
  final String? route;
  final int? tab;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, iconBg, iconFg, sub) = switch (variant) {
      _TileVariant.lime => (
          AppColors.lime,
          AppColors.forest,
          AppColors.forest,
          AppColors.lime,
          AppColors.forest.withValues(alpha: .75)
        ),
      _TileVariant.forest => (
          AppColors.forest,
          Colors.white,
          AppColors.lime,
          AppColors.forest,
          AppColors.white(.7)
        ),
      _TileVariant.white => (
          Colors.white,
          AppColors.ink,
          AppColors.sage,
          AppColors.forest,
          AppColors.muted
        ),
      _TileVariant.amber => (
          Colors.white,
          AppColors.ink,
          AppColors.amberIconBg,
          AppColors.amberIcon,
          AppColors.muted
        ),
    };
    final big = (height ?? 0) > 130;
    return Pressable(
      onTap: () => route != null ? Get.toNamed(route!) : _goTab(tab!),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon,
                size: big ? 52 : 50,
                radius: big ? 17 : 16,
                bg: iconBg,
                fg: iconFg,
                iconSize: big ? 28 : 26,
                fill: variant == _TileVariant.forest ||
                    variant == _TileVariant.lime),
            const Spacer(),
            Text(title,
                style: jakarta(big ? 19 : 18,
                    weight: FontWeight.w800,
                    color: fg,
                    tracking: -.02,
                    height: 1.1)),
            const SizedBox(height: 3),
            Text('Wolof · à traduire',
                style: jakarta(11, style: FontStyle.italic, color: sub)),
          ]),
          if (badge)
            Positioned(
              top: 0,
              right: 0,
              child: Obx(() => Breathing(
                    amount: .1,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 30),
                      height: 30,
                      decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(15)),
                      alignment: Alignment.center,
                      child: Text(
                          '${Get.find<SessionService>().todoCount.value}',
                          style: jakarta(14,
                              weight: FontWeight.w800,
                              color: AppColors.maroon)),
                    ),
                  )),
            ),
        ]),
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.title,
      required this.sub,
      this.onTap});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            IconTile(icon, size: 46, radius: 15, bg: bg, fg: fg, iconSize: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: jakarta(15, weight: FontWeight.w800)),
                    Text(sub,
                        style: jakarta(12.5, color: AppColors.muted),
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),
        ),
      );
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.p});
  final Producer p;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => Get.toNamed(Routes.producer, arguments: p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Hero(
              tag: 'avatar-${p.code}',
              child: CircleAvatar(
                radius: 25,
                backgroundColor: p.tint,
                child: Text(p.initials,
                    style: jakarta(15,
                        weight: FontWeight.w800, color: AppColors.forest)),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.name,
                textAlign: TextAlign.center,
                style: jakarta(13, weight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 2),
            Text(p.village, style: jakarta(11.5, color: AppColors.muted)),
          ]),
        ),
      );
}
