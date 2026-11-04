import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/layout.dart';

/// 10 · Fiche producteur, avec les onglets Parcelles et Alertes (ajoutés).
class ProducerDetailController extends GetxController {
  final session = Get.find<SessionService>();
  final p = ((Get.arguments as Producer?) ?? MockData.producers[5]).obs;
  final tab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (!p.value.archived) session.visit(p.value);
  }

  List<Plot> get plots => session.plotsOf(p.value);

  /// Une fiche archivée est en lecture seule : on la restaure avant d'agir dessus.
  bool _guardArchived() {
    if (!p.value.archived) return false;
    showToast("Fiche archivée · restaurez-la d'abord.",
        icon: Symbols.inventory_2_rounded);
    return true;
  }

  void surveyPlot() {
    if (_guardArchived()) return;
    Get.toNamed(Routes.survey, arguments: p.value);
  }

  /// Ouvre les cultures de la parcelle la plus récente du producteur.
  void openCrops([Plot? plot]) {
    if (_guardArchived()) return;
    final target = plot ?? plots.firstOrNull;
    if (target == null) {
      showToast("Relevez d'abord une parcelle.",
          icon: Symbols.pentagon_rounded);
      return;
    }
    final area =
        double.tryParse(target.area.split(' ').first.replaceAll(',', '.')) ?? 0;
    Get.toNamed(Routes.crops,
        arguments: {'code': target.code, 'owner': p.value, 'area': area});
  }

  // ───────── Menu · modifier · archiver

  Future<void> openMenu() async {
    final action = await Get.bottomSheet<String>(
      _MenuSheet(p: p.value),
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 380),
    );
    switch (action) {
      case 'edit':
        return edit();
      case 'archive':
        return archive();
      case 'restore':
        return restore();
    }
  }

  /// Ouvre le formulaire en mode modification ; il renvoie la fiche mise à jour.
  Future<void> edit() async {
    // Sans type générique : GetX crée la route en `dynamic`, un `toNamed<Producer>` plante au cast.
    final updated = await Get.toNamed(Routes.newProducer, arguments: p.value);
    if (updated is! Producer) return;
    p.value = updated;
    showToast('Fiche modifiée · elle partira au prochain envoi.',
        icon: Symbols.check_circle_rounded);
  }

  /// Archive après confirmation, puis quitte la fiche.
  Future<void> archive() async {
    final ok = await confirmSheet(
      title: 'Archiver ${p.value.name} ?',
      message:
          'La fiche disparaît des listes et de la recherche. Ses parcelles et ses cultures sont conservées. '
          'Vous pourrez la restaurer depuis Producteurs › Archivés.',
      confirmLabel: 'Archiver',
      icon: Symbols.inventory_2_rounded,
    );
    if (!ok) return;
    session.archiveProducer(p.value);
    Get.back();
    showToast('Fiche archivée', icon: Symbols.inventory_2_rounded);
  }

  void restore() {
    p.value = session.restoreProducer(p.value);
    showToast('Fiche restaurée', icon: Symbols.unarchive_rounded);
  }

  /// La maquette montre une mise à jour serveur sur la fiche de Seynabou Seck.
  bool get hasServerUpdate => p.value.code == 'PR-00007';
}

class ProducerDetailView extends GetView<ProducerDetailController> {
  const ProducerDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Obx(() {
          final p = controller.p.value;
          return Column(children: [
            DarkHeader(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SquareIconButton.onDark(onTap: Get.back),
                      Text('Fiche producteur',
                          style: jakarta(13,
                              weight: FontWeight.w700, color: Colors.white)),
                      SquareIconButton.onDark(
                          icon: Symbols.more_horiz_rounded,
                          onTap: controller.openMenu),
                    ]),
                const SizedBox(height: 14),
                Row(children: [
                  Hero(
                      tag: 'avatar-${p.code}',
                      child: _PhotoPlaceholder(initials: p.initials)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      offset: const Offset(30, 0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: jakarta(22,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                    tracking: -.02,
                                    height: 1.1)),
                            const SizedBox(height: 4),
                            Text('${p.code} · ${p.village}',
                                style: mono(11, color: AppColors.white(.6))),
                            const SizedBox(height: 6),
                            Chip2(
                              label: p.archived
                                  ? 'Archivée'
                                  : (p.isNew ? 'Recensé' : 'Membre'),
                              icon: p.archived
                                  ? Symbols.inventory_2_rounded
                                  : null,
                              bg: p.archived
                                  ? AppColors.white(.2)
                                  : (p.isNew
                                      ? AppColors.amberSoft
                                      : AppColors.lime),
                              fg: p.archived ? Colors.white : AppColors.forest,
                              size: 10,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                            ),
                          ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  for (final (i, a) in [
                    (
                      Symbols.call_rounded,
                      'Appeler',
                      false,
                      () => showToast('Appel de ${p.phone}…',
                          icon: Symbols.call_rounded)
                    ),
                    (
                      Symbols.location_on_rounded,
                      'Relever parcelle',
                      true,
                      controller.surveyPlot
                    ),
                    (
                      Symbols.potted_plant_rounded,
                      'Cultures',
                      false,
                      controller.openCrops
                    ),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: FadeSlideIn(
                        delay: Motion.stagger(i, base: 220, step: 70),
                        scale: .7,
                        child: _Action(
                            icon: a.$1,
                            label: a.$2,
                            primary: a.$3,
                            onTap: a.$4),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (p.archived) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          const Sym(Symbols.inventory_2_rounded,
                              size: 22, color: AppColors.amberInk),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Fiche archivée : elle n'apparaît plus dans les listes.",
                              style: jakarta(12,
                                  weight: FontWeight.w600,
                                  color: AppColors.amberInk,
                                  height: 1.35),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip2(
                            label: 'Restaurer',
                            icon: Symbols.unarchive_rounded,
                            bg: AppColors.amberInk,
                            fg: Colors.white,
                            onTap: controller.restore,
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (controller.hasServerUpdate) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.blueSoft,
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spin(
                                  period: Duration(milliseconds: 2400),
                                  child: Sym(Symbols.sync_rounded,
                                      size: 20, color: AppColors.blueInk)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Mise à jour reçue du serveur. La version du serveur remplace la vôtre sur le champ marqué.',
                                  style: jakarta(11,
                                      color: AppColors.blueInk, height: 1.4),
                                ),
                              ),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Obx(() => SegmentedPill(
                        labels: [
                          'Infos',
                          'Parcelles (${controller.plots.length})',
                          'Alertes (${p.isNew ? 0 : 1})'
                        ],
                        index: controller.tab.value,
                        onChanged: (i) => controller.tab.value = i,
                      )),
                  const SizedBox(height: 10),
                  Obx(() => AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                                    begin: const Offset(0, .06),
                                    end: Offset.zero)
                                .animate(a),
                            child: c,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(controller.tab.value),
                          child: switch (controller.tab.value) {
                            0 => _InfoTab(
                                p: p, updated: controller.hasServerUpdate),
                            1 => _PlotsTab(c: controller),
                            _ => _AlertsTab(p: p),
                          },
                        ),
                      )),
                ],
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

/// Menu « ··· » de la fiche : modifier et archiver (ou restaurer si archivée).
class _MenuSheet extends StatelessWidget {
  const _MenuSheet({required this.p});
  final Producer p;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 18, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(p.name,
                    style:
                        jakarta(16, weight: FontWeight.w800, tracking: -.01)),
              ),
              if (!p.archived) ...[
                _MenuTile(
                  icon: Symbols.edit_rounded,
                  bg: AppColors.sage,
                  fg: AppColors.forest,
                  title: 'Modifier la fiche',
                  sub: 'Nom, village, téléphone, organisation…',
                  onTap: () => Get.back(result: 'edit'),
                ),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Symbols.inventory_2_rounded,
                  bg: AppColors.amberSoft,
                  fg: AppColors.amberInk,
                  title: 'Archiver',
                  sub: 'Masque la fiche des listes · restaurable',
                  onTap: () => Get.back(result: 'archive'),
                ),
              ] else
                _MenuTile(
                  icon: Symbols.unarchive_rounded,
                  bg: AppColors.lime,
                  fg: AppColors.forest,
                  title: 'Restaurer la fiche',
                  sub: 'Elle réapparaît dans les listes',
                  onTap: () => Get.back(result: 'restore'),
                ),
            ]),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.title,
      required this.sub,
      required this.onTap});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: .98,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            IconTile(icon, size: 44, radius: 14, bg: bg, fg: fg, iconSize: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: jakarta(14, weight: FontWeight.w800)),
                    Text(sub, style: jakarta(11.5, color: AppColors.muted)),
                  ]),
            ),
            const Sym(Symbols.chevron_right_rounded,
                size: 22, color: AppColors.faint),
          ]),
        ),
      );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _StripePainter(),
          child: SizedBox(
            width: 68,
            height: 68,
            child: Center(
                child:
                    Text('photo', style: mono(9, color: AppColors.white(.6)))),
          ),
        ),
      );
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.white(.04));
    final p = Paint()
      ..color = AppColors.white(.12)
      ..strokeWidth = 6;
    for (double d = -size.height; d < size.width + size.height; d += 17) {
      canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon,
      required this.label,
      required this.primary,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
              color: primary ? AppColors.lime : AppColors.white(.08),
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Sym(icon,
                size: 20,
                color: primary ? AppColors.forest : AppColors.lime,
                fill: primary),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: jakarta(10,
                    weight: primary ? FontWeight.w800 : FontWeight.w700,
                    color: primary ? AppColors.forest : Colors.white,
                    height: 1.1)),
          ]),
        ),
      );
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.p, required this.updated});
  final Producer p;
  final bool updated;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Téléphone', p.phone),
      ('Âge', '${p.age} ans'),
      ('Sexe', p.sex)
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        for (final (i, r) in rows.indexed)
          FadeSlideIn(
              delay: Motion.stagger(i, base: 60, step: 50),
              offset: const Offset(20, 0),
              child: _InfoRow(r.$1, r.$2)),
        FadeSlideIn(
          delay: Motion.stagger(3, base: 60, step: 50),
          offset: const Offset(20, 0),
          child: updated
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOut,
                  builder: (_, t, child) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          Color.lerp(AppColors.blueSoft, AppColors.blueBg, t),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: child,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Village',
                                style: jakarta(12, color: AppColors.blueInk)),
                            const SizedBox(height: 2),
                            Text('avant : ${p.village}',
                                style: jakarta(10, color: AppColors.blueInk)),
                          ]),
                    ),
                    const PulseDot(color: AppColors.blue, size: 7),
                    const SizedBox(width: 4),
                    Text('Diogo',
                        style: jakarta(12,
                            weight: FontWeight.w800, color: AppColors.blueInk)),
                  ]),
                )
              : _InfoRow('Village', p.village),
        ),
        FadeSlideIn(
            delay: Motion.stagger(4, base: 60, step: 50),
            offset: const Offset(20, 0),
            child: _InfoRow('Organisation', p.org, last: true)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Expanded(
              child: Text(label, style: jakarta(12, color: AppColors.muted))),
          Text(value, style: jakarta(12, weight: FontWeight.w700)),
        ]),
      );
}

class _PlotsTab extends StatelessWidget {
  const _PlotsTab({required this.c});
  final ProducerDetailController c;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, plot) in c.plots.indexed) ...[
          FadeSlideIn(
            delay: Motion.stagger(i, base: 60),
            scale: .9,
            child: Pressable(
              scale: .97,
              onTap: () => c.openCrops(plot),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                          Text('${plot.code} · ${plot.area}',
                              style: jakarta(13, weight: FontWeight.w800)),
                          Text(plot.crops,
                              style: jakarta(11, color: AppColors.muted)),
                        ]),
                  ),
                  Chip2(
                    label: plot.status,
                    bg: plot.statusBg,
                    fg: plot.statusInk,
                    size: 10,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ]),
              ),
            ),
          ),
        ],
        FadeSlideIn(
          delay: Motion.stagger(2, base: 60),
          child: FlatButton(
            label: 'Relever une nouvelle parcelle',
            icon: Symbols.add_location_alt_rounded,
            dashed: true,
            height: 48,
            radius: 16,
            size: 13,
            onTap: () => Get.toNamed(Routes.survey, arguments: c.p),
          ),
        ),
      ]);
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.p});
  final Producer p;

  @override
  Widget build(BuildContext context) => p.isNew
      ? FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const IconTile(Symbols.verified_rounded, size: 40, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Aucune alerte. Le serveur vérifiera la fiche à l\'envoi.',
                      style: jakarta(12, weight: FontWeight.w600))),
            ]),
          ),
        )
      : FadeSlideIn(
          scale: .9,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconTile(Symbols.wc_rounded,
                  size: 36,
                  radius: 12,
                  bg: AppColors.redSoft,
                  fg: AppColors.redInk,
                  iconSize: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sexe incohérent avec le numéro de CNI',
                          style: jakarta(13, weight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                          'Le 1er chiffre de la CNI indique un homme ; la fiche dit « ${p.sex} ».',
                          style:
                              jakarta(11, color: AppColors.muted, height: 1.4)),
                    ]),
              ),
              const SizedBox(width: 6),
              Pressable(
                onTap: () => Get.toNamed(Routes.fix,
                    arguments: MockData.syncIssues.first),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.forest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('Corriger',
                      style: jakarta(11,
                          weight: FontWeight.w800, color: AppColors.lime)),
                ),
              ),
            ]),
          ),
        );
}
