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

/// 03 · Activation · choix du PIN, suivi d'une confirmation (écran ajouté).
class PinCreateController extends GetxController {
  final entry = ''.obs;
  final confirming = false.obs;
  final shake = 0.obs;
  final mismatch = false.obs;
  String _first = '';

  /// Ouvert depuis le profil (« Changer mon code PIN ») plutôt qu'à l'activation.
  final bool isChange = Get.arguments == 'change';

  void digit(String d) {
    if (entry.value.length >= 4) return;
    mismatch.value = false;
    entry.value += d;
    if (entry.value.length == 4)
      Future.delayed(const Duration(milliseconds: 260), _complete);
  }

  void backspace() {
    if (entry.value.isNotEmpty)
      entry.value = entry.value.substring(0, entry.value.length - 1);
  }

  void _complete() {
    if (!confirming.value) {
      _first = entry.value;
      entry.value = '';
      confirming.value = true;
      return;
    }
    if (entry.value == _first) {
      Get.find<SessionService>().pin.value = _first;
      if (isChange) {
        Get.back();
        showToast('Code PIN modifié.', icon: Symbols.check_circle_rounded);
      } else {
        Get.offAllNamed(Routes.download);
      }
    } else {
      mismatch.value = true;
      shake.value++;
      entry.value = '';
    }
  }

  void back() {
    if (confirming.value) {
      confirming.value = false;
      entry.value = '';
      mismatch.value = false;
    } else {
      Get.back();
    }
  }
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
                  final confirm = controller.confirming.value;
                  final bad = controller.mismatch.value;
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
                    child: Column(key: ValueKey('$confirm$bad'), children: [
                      Text(
                          confirm
                              ? 'Confirmez le code PIN'
                              : 'Choisissez un code PIN',
                          textAlign: TextAlign.center,
                          style: display(28, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(
                        bad
                            ? 'Les deux codes sont différents. Recommencez.'
                            : confirm
                                ? 'Tapez le même code une seconde fois'
                                : '4 chiffres, faciles à retenir',
                        style: jakarta(13,
                            color: bad ? AppColors.coral : AppColors.white(.65),
                            weight: bad ? FontWeight.w700 : FontWeight.w500),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 24),
                Obx(() => Shake(
                    trigger: controller.shake.value,
                    child: PinBoxes(length: controller.entry.value.length))),
                const Spacer(),
                PinKeypad(
                    onDigit: controller.digit,
                    onBackspace: controller.backspace),
                const SizedBox(height: 12),
                Obx(() => AnimatedOpacity(
                      duration: Motion.medium,
                      opacity: controller.confirming.value ? 1 : 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Sym(Symbols.lock_rounded,
                                size: 15, color: AppColors.lime),
                            const SizedBox(width: 6),
                            Text('Le code reste sur ce téléphone',
                                style: jakarta(11,
                                    weight: FontWeight.w600,
                                    color: AppColors.white(.8))),
                          ]),
                    )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
