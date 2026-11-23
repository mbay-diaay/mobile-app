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

/// Validation d'une géométrie (MO-25) : « validée » ou « à reprendre » + motif.
class PlotValidateController extends GetxController {
  late final Producer owner;
  late final Plot plot;
  final decision = RxnString(); // validée | à reprendre
  final motif = TextEditingController();
  final shake = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = (Get.arguments as Map?) ?? {};
    owner = (args['owner'] as Producer?) ?? MockData.producers[5];
    plot = (args['plot'] as Plot?) ??
        Plot('PA-0000', '0,20 ha', '—', 'Relevée', AppColors.blueSoft,
            AppColors.blueInk);
  }

  bool get canSave {
    if (decision.value == null) return false;
    if (decision.value == 'à reprendre') return motif.text.trim().length >= 4;
    return true;
  }

  void choose(String value) {
    decision.value = value;
    if (value == 'validée') motif.clear();
  }

  void save() {
    if (!canSave) {
      shake.value++;
      return;
    }
    final ok = decision.value == 'validée';
    Get.find<SessionService>().setPlotStatus(
      owner,
      plot,
      status: ok ? 'Validée' : 'À reprendre',
      statusBg: ok ? AppColors.sage : AppColors.amberSoft,
      statusInk: ok ? AppColors.forest : AppColors.amberInk,
      motif: ok ? null : motif.text.trim(),
    );
    Get.offNamed(Routes.success, arguments: {
      'title': ok ? 'Géométrie validée' : 'À reprendre',
      'sub': ok
          ? '${plot.code} · ${owner.name}\nLa validation partira au prochain envoi.'
          : '${plot.code} · motif : ${motif.text.trim()}',
      'cta': 'Retour à la fiche',
      'route': Routes.producer,
      'args': owner,
    });
  }

  @override
  void onClose() {
    motif.dispose();
    super.onClose();
  }
}

class PlotValidateView extends GetView<PlotValidateController> {
  const PlotValidateView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: FillScroll(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  child: Row(children: [
                    SquareIconButton(onTap: Get.back),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Valider la géométrie', style: display(22))),
                  ]),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: Motion.stagger(1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.plot.code,
                            style: jakarta(18, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${c.owner.name} · ${c.plot.area}',
                            style: jakarta(13, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        Text(
                          'La superficie mobile est indicative. Une nouvelle version est créée : rien n’est écrasé.',
                          style:
                              jakarta(12, color: AppColors.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: Motion.stagger(2),
                  child: Text('Décision',
                      style: jakarta(14, weight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Obx(() => Row(children: [
                      Expanded(
                        child: _Choice(
                          label: 'Validée',
                          icon: Symbols.verified_rounded,
                          selected: c.decision.value == 'validée',
                          onTap: () => c.choose('validée'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Choice(
                          label: 'À reprendre',
                          icon: Symbols.replay_rounded,
                          selected: c.decision.value == 'à reprendre',
                          danger: true,
                          onTap: () => c.choose('à reprendre'),
                        ),
                      ),
                    ])),
                Obx(() {
                  if (c.decision.value != 'à reprendre') {
                    return const SizedBox.shrink();
                  }
                  return FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Shake(
                        trigger: c.shake.value,
                        child: TextField(
                          controller: c.motif,
                          onChanged: (_) => c.decision.refresh(),
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Motif (obligatoire)',
                            hintText: 'Ex. coin nord trop imprécis',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                const SizedBox(height: 16),
                Obx(() => SwipeCta(
                      label: 'Glissez pour enregistrer',
                      onConfirm: c.canSave ? c.save : null,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (danger ? AppColors.amberSoft : AppColors.lime)
        : Colors.white;
    final fg = danger ? AppColors.amberInk : AppColors.forest;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? fg.withValues(alpha: .35) : AppColors.faint),
        ),
        child: Column(children: [
          Sym(icon, size: 28, color: fg, fill: selected),
          const SizedBox(height: 8),
          Text(label, style: jakarta(14, weight: FontWeight.w800, color: fg)),
        ]),
      ),
    );
  }
}
