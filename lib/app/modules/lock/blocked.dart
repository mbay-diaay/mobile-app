import 'dart:async';

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
import '../../widgets/ring_progress.dart';

/// 06 · PIN bloqué : compte à rebours de 5 minutes.
class BlockedController extends GetxController {
  static const total = 300;
  final seconds = (total - 1).obs;
  Timer? _timer;

  String get label =>
      '${seconds.value ~/ 60}:${(seconds.value % 60).toString().padLeft(2, '0')}';

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds.value <= 0) return retry();
      seconds.value--;
    });
  }

  void retry() {
    _timer?.cancel();
    Get.find<SessionService>().failedAttempts.value = 0;
    Get.offAllNamed(Routes.unlock);
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

class BlockedView extends GetView<BlockedController> {
  const BlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.maroonGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                const FadeSlideIn(
                  scale: .2,
                  offset: Offset.zero,
                  curve: Curves.elasticOut,
                  duration: Duration(milliseconds: 1200),
                  child: Shake(
                    trigger: 1,
                    child: IconTile(Symbols.lock_clock_rounded,
                        size: 72,
                        radius: 24,
                        iconSize: 36,
                        bg: AppColors.coral,
                        fg: AppColors.maroon,
                        fill: true),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: Text("Trop d'essais",
                        style: display(30, color: Colors.white))),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 240,
                    child: Text(
                      'Pour protéger les données, le téléphone est bloqué quelques minutes.',
                      textAlign: TextAlign.center,
                      style:
                          jakarta(14, color: AppColors.white(.7), height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  scale: .6,
                  child: Obx(() => TweenAnimationBuilder<double>(
                        tween: Tween(
                            end: controller.seconds.value /
                                BlockedController.total),
                        duration: const Duration(milliseconds: 900),
                        builder: (_, v, __) => RingProgress(
                          value: v,
                          size: 200,
                          thickness: 10,
                          color: AppColors.coral,
                          track: AppColors.white(.1),
                          inner: AppColors.maroonRing,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedSwitcher(
                              duration: Motion.fast,
                              transitionBuilder: (c, a) => FadeTransition(
                                opacity: a,
                                child: SlideTransition(
                                  position: Tween(
                                          begin: const Offset(0, -.3),
                                          end: Offset.zero)
                                      .animate(a),
                                  child: c,
                                ),
                              ),
                              child: Text(controller.label,
                                  key: ValueKey(controller.seconds.value),
                                  style: mono(52,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      tracking: -.04)),
                            ),
                            Text('avant nouvel essai',
                                style:
                                    jakarta(11, color: AppColors.white(.55))),
                          ]),
                        ),
                      )),
                ),
                const Spacer(),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: FlatButton(
                    label: 'Réessayer (prototype)',
                    height: 56,
                    bg: Colors.transparent,
                    fg: Colors.white,
                    border: AppColors.white(.3),
                    size: 15,
                    onTap: controller.retry,
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
