import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/pin_widgets.dart';

/// 05 · Déverrouillage par PIN (prototype : 1234). Trois erreurs → écran 06.
class UnlockController extends GetxController {
  final session = Get.find<SessionService>();
  final entry = ''.obs;
  final error = false.obs;
  final success = false.obs;
  final shake = 0.obs;

  int get remaining =>
      SessionService.maxAttempts - session.failedAttempts.value;

  void digit(String d) {
    if (entry.value.length >= 4 || success.value) return;
    error.value = false;
    entry.value += d;
    if (entry.value.length == 4)
      Future.delayed(const Duration(milliseconds: 180), _check);
  }

  void backspace() {
    if (entry.value.isNotEmpty)
      entry.value = entry.value.substring(0, entry.value.length - 1);
  }

  Future<void> _check() async {
    if (session.checkPin(entry.value)) {
      success.value = true;
      await Future.delayed(const Duration(milliseconds: 650));
      Get.offAllNamed(Routes.shell);
      return;
    }
    error.value = true;
    shake.value++;
    await Future.delayed(const Duration(milliseconds: 450));
    entry.value = '';
    if (session.locked) Get.offAllNamed(Routes.blocked);
  }
}

class UnlockView extends GetView<UnlockController> {
  const UnlockView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.forestGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Column(children: [
                const SizedBox(height: 24),
                Obx(() => FadeSlideIn(
                      scale: .3,
                      offset: Offset.zero,
                      curve: Curves.elasticOut,
                      duration: const Duration(milliseconds: 1200),
                      child: AnimatedScale(
                        scale: controller.success.value ? 1.15 : 1,
                        duration: Motion.medium,
                        curve: Curves.elasticOut,
                        child: Breathing(
                          amount: .04,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppColors.lime.withValues(alpha: .15),
                                    spreadRadius: 8)
                              ],
                            ),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: Motion.medium,
                              child: controller.success.value
                                  ? const Icon(Symbols.lock_open_rounded,
                                      key: ValueKey('o'),
                                      size: 34,
                                      color: AppColors.forest)
                                  : Text('MD',
                                      key: const ValueKey('m'),
                                      style: jakarta(26,
                                          weight: FontWeight.w800,
                                          color: AppColors.forest,
                                          tracking: -.02)),
                            ),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Column(children: [
                    Text('Bonjour,',
                        style: jakarta(13, color: AppColors.white(.65))),
                    Text(session.technician,
                        style: display(30, color: Colors.white, height: 1.1)),
                    const SizedBox(height: 8),
                    Obx(() => AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Text(
                            controller.error.value
                                ? 'Code incorrect · ${controller.remaining} essai${controller.remaining > 1 ? 's' : ''} restant${controller.remaining > 1 ? 's' : ''}'
                                : 'Tapez votre code PIN · prototype : ${session.pin.value}',
                            key: ValueKey(controller.error.value),
                            style: jakarta(12,
                                color: controller.error.value
                                    ? AppColors.coral
                                    : AppColors.white(.6),
                                weight: controller.error.value
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                        )),
                  ]),
                ),
                const SizedBox(height: 22),
                Obx(() => Shake(
                      trigger: controller.shake.value,
                      child: PinDots(
                          length: controller.entry.value.length,
                          error: controller.error.value),
                    )),
                const Spacer(),
                PinKeypad(
                    onDigit: controller.digit,
                    onBackspace: controller.backspace),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.white(.08),
                        borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Sym(Symbols.wifi_off_rounded,
                          size: 15, color: AppColors.lime),
                      const SizedBox(width: 6),
                      Text('Fonctionne aussi sans réseau',
                          style: jakarta(11,
                              weight: FontWeight.w600,
                              color: AppColors.white(.8))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
