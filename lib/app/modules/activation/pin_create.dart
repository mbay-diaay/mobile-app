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

/// Étapes du parcours PIN.
enum _PinPhase { verifyCurrent, choose, confirm }

/// 03 · Activation · choix du PIN, ou changement depuis le profil (vérif. d’abord).
class PinCreateController extends GetxController {
  final entry = ''.obs;
  final phase = _PinPhase.choose.obs;
  final shake = 0.obs;
  final error = false.obs;
  String _first = '';

  /// Ouvert depuis le profil (« Changer mon code PIN ») plutôt qu'à l'activation.
  final bool isChange = Get.arguments == 'change';

  @override
  void onInit() {
    super.onInit();
    if (isChange) phase.value = _PinPhase.verifyCurrent;
  }

  void digit(String d) {
    if (entry.value.length >= 4) return;
    error.value = false;
    entry.value += d;
    if (entry.value.length == 4) {
      Future.delayed(const Duration(milliseconds: 260), _complete);
    }
  }

  void backspace() {
    if (entry.value.isNotEmpty) {
      entry.value = entry.value.substring(0, entry.value.length - 1);
    }
  }

  void _complete() {
    final session = Get.find<SessionService>();
    switch (phase.value) {
      case _PinPhase.verifyCurrent:
        if (session.matchesPin(entry.value)) {
          entry.value = '';
          phase.value = _PinPhase.choose;
        } else {
          error.value = true;
          shake.value++;
          entry.value = '';
        }
      case _PinPhase.choose:
        _first = entry.value;
        entry.value = '';
        phase.value = _PinPhase.confirm;
      case _PinPhase.confirm:
        if (entry.value == _first) {
          session.pin.value = _first;
          if (isChange) {
            Get.back();
            showToast('pin.changed'.tr, icon: Symbols.check_circle_rounded);
          } else {
            Get.offAllNamed(Routes.download);
          }
        } else {
          error.value = true;
          shake.value++;
          entry.value = '';
          phase.value = _PinPhase.choose;
          _first = '';
        }
    }
  }

  void back() {
    switch (phase.value) {
      case _PinPhase.verifyCurrent:
        Get.back();
      case _PinPhase.choose:
        if (isChange) {
          phase.value = _PinPhase.verifyCurrent;
          entry.value = '';
          error.value = false;
        } else {
          Get.back();
        }
      case _PinPhase.confirm:
        phase.value = _PinPhase.choose;
        entry.value = '';
        error.value = false;
        _first = '';
    }
  }

  String get title => switch (phase.value) {
        _PinPhase.verifyCurrent => 'pin.current'.tr,
        _PinPhase.choose => 'pin.choose'.tr,
        _PinPhase.confirm => 'pin.confirm'.tr,
      };

  String get subtitle => switch (phase.value) {
        _PinPhase.verifyCurrent =>
          error.value ? 'pin.wrong'.tr : '4 chiffres',
        _PinPhase.choose => '4 chiffres',
        _PinPhase.confirm =>
          error.value ? 'pin.mismatch'.tr : 'Retapez le même code',
      };
}

class PinCreateView extends GetView<PinCreateController> {
  const PinCreateView({super.key});

  @override
  Widget build(BuildContext context) {
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
                FadeSlideIn(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SquareIconButton.onDark(onTap: controller.back),
                        if (!controller.isChange) ...[
                          const StepLabel(3),
                          const StepIndicator(step: 3)
                        ],
                      ]),
                ),
                const SizedBox(height: 32),
                Obx(() {
                  final phase = controller.phase.value;
                  final bad = controller.error.value;
                  return AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position:
                            Tween(begin: const Offset(.25, 0), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: a, curve: Motion.smooth)),
                        child: c,
                      ),
                    ),
                    child: Column(key: ValueKey('$phase$bad'), children: [
                      Text(controller.title,
                          textAlign: TextAlign.center,
                          style: display(28, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(controller.subtitle,
                          textAlign: TextAlign.center,
                          style: jakarta(13,
                              color: bad
                                  ? AppColors.coral
                                  : AppColors.white(.65))),
                    ]),
                  );
                }),
                const SizedBox(height: 28),
                Obx(() => Shake(
                      trigger: controller.shake.value,
                      child: PinDots(
                        length: controller.entry.value.length,
                        error: controller.error.value,
                      ),
                    )),
                const Spacer(),
                PinKeypad(
                  onDigit: controller.digit,
                  onBackspace: controller.backspace,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
