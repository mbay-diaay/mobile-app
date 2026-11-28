import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// 06 · PIN bloqué : compte à rebours basé sur [SessionService.lockedUntilMs].
class BlockedController extends GetxController {
  static const total = 180;
  final seconds = total.obs;
  Timer? _timer;

  String get minutesLabel => '${seconds.value ~/ 60}';
  String get secondsLabel => (seconds.value % 60).toString().padLeft(2, '0');

  @override
  void onInit() {
    super.onInit();
    final session = Get.find<SessionService>();
    seconds.value = session.lockRemainingSeconds.clamp(1, total);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = session.lockRemainingSeconds;
      if (left <= 0) {
        retry();
        return;
      }
      seconds.value = left;
    });
  }

  Future<void> retry() async {
    _timer?.cancel();
    await Get.find<SessionService>().clearPinLock();
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
                            // Chaque seconde, seules les secondes s'animent ; les minutes
                            // ne bougent que lorsqu'elles changent.
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              _RollingText(controller.minutesLabel),
                              Text(':', style: _digitStyle),
                              _RollingText(controller.secondsLabel),
                            ]),
                            Text('avant nouvel essai',
                                style:
                                    jakarta(11, color: AppColors.white(.55))),
                          ]),
                        ),
                      )),
                ),
                const Spacer(),
                if (kDebugMode)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 450),
                    child: FlatButton(
                      label: 'Réessayer (debug)',
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

final _digitStyle =
    mono(52, weight: FontWeight.w700, color: Colors.white, tracking: -.04);

/// Texte dont le changement de valeur descend du haut vers le bas : la nouvelle
/// valeur entre par le haut, l'ancienne sort par le bas.
class _RollingText extends StatelessWidget {
  const _RollingText(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(value);
    return AnimatedSwitcher(
      duration: Motion.fast,
      transitionBuilder: (child, animation) {
        final entering = child.key == current;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
                    begin: Offset(0, entering ? -.4 : .4), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );
      },
      child: Text(value, key: current, style: _digitStyle),
    );
  }
}
