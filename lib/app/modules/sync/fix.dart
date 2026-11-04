import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Correction d'une erreur signalée par le serveur (écran ajouté).
class FixController extends GetxController {
  final SyncIssue issue =
      (Get.arguments as SyncIssue?) ?? MockData.syncIssues.first;
  late final text = TextEditingController(
      text: issue.value.replaceAll('+221 ', '').replaceAll(' ', ''));
  final value = ''.obs;
  final shake = 0.obs;

  bool get isPhone => issue.field == 'Téléphone';
  int get expected => isPhone ? 9 : 13;
  bool get valid => value.value.length == expected;

  @override
  void onInit() {
    super.onInit();
    value.value = text.text;
  }

  void save() {
    if (!valid) {
      shake.value++;
      return;
    }
    final s = Get.find<SessionService>();
    if (s.toFix.contains(issue)) s.resolveIssue(issue);
    Get.offNamed(Routes.success, arguments: {
      'title': 'Correction enregistrée',
      'sub': '${issue.title} · ${issue.owner}\nElle partira au prochain envoi.',
      'cta': 'Voir la synchronisation',
      'route': Routes.sync,
    });
  }

  @override
  void onClose() {
    text.dispose();
    super.onClose();
  }
}

class FixView extends GetView<FixController> {
  const FixView({super.key});

  @override
  Widget build(BuildContext context) {
    final issue = controller.issue;
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: FillScroll(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: Row(children: [
                      SquareIconButton(
                          icon: Symbols.close_rounded, onTap: Get.back),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Corriger', style: display(22))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    scale: .9,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.maroon,
                          borderRadius: BorderRadius.circular(24)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Breathing(
                                child: IconTile(issue.icon,
                                    bg: AppColors.coral, fg: AppColors.maroon)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(issue.title,
                                        style: jakarta(17,
                                            weight: FontWeight.w800,
                                            color: Colors.white,
                                            tracking: -.02)),
                                    Text('Fiche · ${issue.owner}',
                                        style: jakarta(11,
                                            color: AppColors.white(.6))),
                                    const SizedBox(height: 6),
                                    Text(issue.detail,
                                        style: jakarta(12,
                                            color: AppColors.white(.8),
                                            height: 1.4)),
                                  ]),
                            ),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Text(issue.field.toUpperCase(),
                        style: jakarta(11,
                            weight: FontWeight.w700,
                            tracking: .06,
                            color: AppColors.muted)),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 250),
                    child: Obx(() => Shake(
                          trigger: controller.shake.value,
                          child: AnimatedContainer(
                            duration: Motion.medium,
                            height: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: controller.valid
                                      ? AppColors.forest
                                      : AppColors.red,
                                  width: 2),
                            ),
                            child: Row(children: [
                              if (controller.isPhone) ...[
                                Text('+221',
                                    style: jakarta(18,
                                        weight: FontWeight.w700,
                                        color: AppColors.muted)),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: TextField(
                                  controller: controller.text,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  onChanged: controller.value.call,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                        controller.expected)
                                  ],
                                  style: jakarta(20,
                                      weight: FontWeight.w700, tracking: .02),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: Motion.medium,
                                transitionBuilder: (w, a) => ScaleTransition(
                                    scale: CurvedAnimation(
                                        parent: a, curve: Curves.elasticOut),
                                    child: w),
                                child: controller.valid
                                    ? const Icon(Symbols.check_circle_rounded,
                                        key: ValueKey(1),
                                        color: AppColors.forest,
                                        fill: 1)
                                    : const Icon(Symbols.error_rounded,
                                        key: ValueKey(0),
                                        color: AppColors.red,
                                        fill: 1),
                              ),
                            ]),
                          ),
                        )),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => Text(
                        '${controller.value.value.length} / ${controller.expected} chiffres',
                        style: mono(11,
                            weight: FontWeight.w700,
                            color: controller.valid
                                ? AppColors.forest
                                : AppColors.red),
                      )),
                  const Spacer(),
                  const SizedBox(height: 16),
                  Obx(() => SwipeCta.dark(
                        label: 'Glissez pour enregistrer',
                        onConfirm: controller.valid ? controller.save : null,
                      )),
                ]),
          ),
        ),
      ),
    );
  }
}
