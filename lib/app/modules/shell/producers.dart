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
import '../../widgets/layout.dart';
import 'shell.dart';

/// 09 · Recherche producteur
class ProducersController extends GetxController {
  final session = Get.find<SessionService>();
  final query = ''.obs;

  /// Vue des fiches archivées (restaurables) au lieu des fiches actives.
  final showArchived = false.obs;

  /// Total de la SCOOP : 212 fiches téléchargées + celles créées ici, hors archivées.
  int get total =>
      212 + session.activeProducers.length - MockData.producers.length;

  List<Producer> get results {
    final q = query.value.trim().toLowerCase();
    final all = showArchived.value
        ? session.archivedProducers
        : session.activeProducers;
    if (q.isEmpty) return all;
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.village.toLowerCase().contains(q) ||
            p.phone.replaceAll(' ', '').contains(q))
        .toList();
  }
}

class ProducersTab extends GetView<ProducersController> {
  const ProducersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    final bottom = ShellView.bottomInset(context);
    return Stack(children: [
      Column(children: [
        DarkHeader(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Producteurs', style: display(26, color: Colors.white)),
            const SizedBox(height: 12),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Sym(Symbols.search_rounded, color: AppColors.forest),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => controller.query.value = v,
                    style: jakarta(14, weight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Nom, village ou téléphone',
                      hintStyle: jakarta(14, color: AppColors.muted),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Obx(() => controller.showArchived.value
                ? Text('Fiches archivées · touchez une fiche pour la restaurer',
                    style: jakarta(11,
                        weight: FontWeight.w600, color: AppColors.white(.65)))
                : Text.rich(TextSpan(
                    style: jakarta(11, color: AppColors.white(.65)),
                    children: [
                        TextSpan(
                            text: '${controller.total}',
                            style: jakarta(11,
                                weight: FontWeight.w800,
                                color: AppColors.lime)),
                        TextSpan(text: ' producteurs · SCOOP ${s.scoop}'),
                      ]))),
            // Raccourcis sous le décompte : fiches à corriger, et accès aux fiches archivées
            // (seulement s'il y en a, ou si on les consulte).
            Obx(() {
              final fix = s.toFix.length;
              final n = s.archivedProducers.length;
              final on = controller.showArchived.value;
              if (fix == 0 && n == 0 && !on) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (fix > 0)
                    Chip2(
                        label: '$fix à corriger',
                        icon: Symbols.error_rounded,
                        onTap: () => Get.toNamed(Routes.sync)),
                  if (n > 0 || on)
                    Chip2(
                      label: on ? 'Retour aux fiches' : 'Archivées · $n',
                      icon: on
                          ? Symbols.arrow_back_rounded
                          : Symbols.inventory_2_rounded,
                      bg: on ? AppColors.lime : AppColors.white(.12),
                      fg: on ? AppColors.forest : Colors.white,
                      onTap: () => controller.showArchived.toggle(),
                    ),
                ]),
              );
            }),
          ]),
        ),
        Expanded(
          child: Obx(() {
            final list = controller.results;
            if (list.isEmpty) {
              return FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const IconTile(Symbols.person_search_rounded,
                        size: 56, radius: 18, bg: AppColors.sage, iconSize: 28),
                    const SizedBox(height: 12),
                    Text(
                        controller.showArchived.value
                            ? 'Aucune fiche archivée'
                            : 'Aucun producteur trouvé',
                        style: jakarta(15, weight: FontWeight.w800)),
                    Text(
                        controller.showArchived.value
                            ? 'Les fiches archivées apparaissent ici.'
                            : 'Vérifiez l\'orthographe ou créez une fiche.',
                        style: jakarta(12, color: AppColors.muted)),
                  ]),
                ),
              );
            }
            return ListView.separated(
              key: ValueKey(
                  '${controller.query.value}|${controller.showArchived.value}'),
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 70),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => FadeSlideIn(
                delay: Motion.stagger(i, step: 45, base: 120),
                offset: const Offset(40, 0),
                child: ProducerRow(p: list[i]),
              ),
            );
          }),
        ),
      ]),
      Positioned(
        right: 20,
        bottom: bottom,
        child: FadeSlideIn(
          delay: const Duration(milliseconds: 500),
          scale: 0,
          offset: Offset.zero,
          curve: Curves.elasticOut,
          duration: const Duration(milliseconds: 1000),
          child: Pressable(
            onTap: () => Get.toNamed(Routes.newProducer),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.forest.withValues(alpha: .35),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: const Icon(Symbols.person_add_rounded,
                  size: 28, color: AppColors.forest),
            ),
          ),
        ),
      ),
    ]);
  }
}

class ProducerRow extends StatelessWidget {
  const ProducerRow({super.key, required this.p, this.trailing});
  final Producer p;

  /// Information affichée avant le chevron (heure d'enregistrement…).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: .97,
        onTap: () => Get.toNamed(Routes.producer, arguments: p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Hero(
              tag: 'avatar-${p.code}',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: p.tint, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Text(p.initials,
                    style: jakarta(15,
                        weight: FontWeight.w800, color: AppColors.forest)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: jakarta(15,
                            weight: FontWeight.w800, tracking: -.01)),
                    const SizedBox(height: 2),
                    Text(p.subtitle,
                        style: jakarta(12.5, color: AppColors.muted)),
                  ]),
            ),
            if (p.archived)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip2(
                    label: 'Archivée',
                    icon: Symbols.inventory_2_rounded,
                    bg: AppColors.sand,
                    fg: AppColors.muted,
                    size: 10,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
              )
            else if (p.isNew)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip2(
                    label: 'Nouveau',
                    bg: AppColors.lime,
                    fg: AppColors.forest,
                    size: 10,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
              ),
            if (trailing != null)
              Padding(
                  padding: const EdgeInsets.only(right: 4), child: trailing),
            const Sym(Symbols.chevron_right_rounded,
                size: 24, color: AppColors.faint),
          ]),
        ),
      );
}
