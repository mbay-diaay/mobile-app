import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/producer_seed.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// Accueil auth producteur — même charte que l’activation technicien.
class ProducerWelcomeView extends StatelessWidget {
  const ProducerWelcomeView({super.key});

  /// Compte mock Aïssa Diop — sans API, pour la démo.
  Future<void> _enterSeed() async {
    await Get.find<SessionService>().setAppRole(AppRole.producer);
    Get.offAllNamed(Routes.producerHome, arguments: ProducerSeed.user);
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        backgroundColor: AppColors.forest,
        body: Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(
                    child: TextButton.icon(
                      onPressed: () async {
                        await Get.find<SessionService>().clearAppRole();
                        Get.offAllNamed(Routes.roleGate);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.white(.8),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Symbols.arrow_back_rounded, size: 18),
                      label: Text('common.changeRole'.tr,
                          style: jakarta(13, weight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: Motion.stagger(0),
                    scale: .4,
                    curve: Motion.spring,
                    duration: Motion.slow,
                    child: const IconTile(Symbols.agriculture_rounded,
                        size: 56, radius: 18, iconSize: 30, fill: true),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('auth.prod.title'.tr,
                        style: display(30, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Expanded(
            child: RisingSheet(
              child: FillScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'auth.prod.lead'.tr,
                      style: jakarta(14, color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      delay: Motion.stagger(2),
                      child: SwipeCta(
                        label: 'common.swipeCreate'.tr,
                        onConfirm: () async =>
                            Get.toNamed(Routes.producerRegister),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: Motion.stagger(3),
                      child: SwipeCta.dark(
                        label: 'common.swipeConnect'.tr,
                        onConfirm: () async =>
                            Get.toNamed(Routes.producerLogin),
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: TextButton(
                        onPressed: _enterSeed,
                        child: Text('auth.prod.seed'.tr,
                            style: jakarta(12,
                                weight: FontWeight.w700,
                                color: AppColors.forest)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'auth.prod.phoneOnly'.tr,
                      textAlign: TextAlign.center,
                      style: jakarta(11, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
