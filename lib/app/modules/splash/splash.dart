import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/layout.dart';

/// Écran de démarrage (ajouté : absent du PDF).
class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    // Téléphone déjà activé : on va droit au PIN, sans refaire l'activation.
    final activated = Get.find<SessionService>().activated.value;
    Future.delayed(const Duration(milliseconds: 2600),
        () => Get.offAllNamed(activated ? Routes.unlock : Routes.phone));
  }
}

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.forestGradient),
          child: Stack(children: [
            // Grands cercles concentriques qui s'ouvrent derrière le logo.
            for (var i = 0; i < 3; i++)
              Center(
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 150 + i * 160),
                  duration: const Duration(milliseconds: 1400),
                  offset: Offset.zero,
                  scale: .3,
                  curve: Motion.smooth,
                  child: Container(
                    width: 180.0 + i * 120,
                    height: 180.0 + i * 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              AppColors.lime.withValues(alpha: .14 - i * .04),
                          width: 1.5),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FadeSlideIn(
                  offset: Offset.zero,
                  scale: .2,
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.elasticOut,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.lime.withValues(alpha: .35),
                            blurRadius: 40,
                            spreadRadius: 4)
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Symbols.eco_rounded,
                        size: 52, color: AppColors.forest, fill: 1),
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: Text('Mbay Diaay',
                      style: display(40, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: Text('Recensement des producteurs · Niayes',
                      style: jakarta(13, color: AppColors.white(.65))),
                ),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 900),
                child: Column(children: [
                  const _LoadingBar(),
                  const SizedBox(height: 14),
                  Text('TECHNICIEN · v0.1.0',
                      style: mono(10,
                          weight: FontWeight.w700, color: AppColors.lime)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        height: 6,
        decoration: BoxDecoration(
            color: AppColors.white(.12),
            borderRadius: BorderRadius.circular(3)),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeInOutCubic,
          builder: (_, v, __) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(3))),
          ),
        ),
      );
}
