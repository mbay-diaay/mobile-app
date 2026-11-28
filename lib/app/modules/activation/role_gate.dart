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

/// Choix du profil : même charte que l’activation technicien (forêt + feuille crème).
class RoleGateController extends GetxController {
  Future<void> choose(AppRole role) async {
    final session = Get.find<SessionService>();
    await session.setAppRole(role);
    if (role == AppRole.technician && session.activated.value) {
      // Déjà activé (ex. après « Changer de rôle ») → PIN, pas l’écran téléphone.
      Get.offAllNamed(Routes.unlock);
      return;
    }
    Get.offAllNamed(Routes.authIntent, arguments: role);
  }
}

class RoleGateView extends GetView<RoleGateController> {
  const RoleGateView({super.key});

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
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FadeSlideIn(
                    child: IconTile(Symbols.spa_rounded,
                        size: 56, radius: 18, iconSize: 30, fill: true),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('role.title'.tr,
                        style: display(30, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: Motion.stagger(2),
                    child: Text(
                      'role.lead'.tr,
                      style: jakarta(14,
                          color: AppColors.white(.72), height: 1.4),
                    ),
                  ),
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
                    FadeSlideIn(
                      delay: Motion.stagger(2),
                      child: _RoleCard(
                        icon: Symbols.engineering_rounded,
                        title: 'role.tech'.tr,
                        subtitle: 'role.techSub'.tr,
                        onTap: () =>
                            controller.choose(AppRole.technician),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: Motion.stagger(3),
                      child: _RoleCard(
                        icon: Symbols.agriculture_rounded,
                        title: 'role.producer'.tr,
                        subtitle: 'role.producerSub'.tr,
                        onTap: () => controller.choose(AppRole.producer),
                        accent: true,
                      ),
                    ),
                    const Spacer(),
                    FadeSlideIn(
                      delay: Motion.stagger(4),
                      child: Text(
                        'role.footer'.tr,
                        textAlign: TextAlign.center,
                        style: jakarta(12, color: AppColors.muted),
                      ),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
          color: accent ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: accent
              ? null
              : Border.all(color: AppColors.sage, width: 1.5),
        ),
        child: Row(children: [
          IconTile(
            icon,
            size: 52,
            radius: 16,
            iconSize: 26,
            bg: accent ? AppColors.lime : AppColors.sage,
            fill: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: jakarta(17,
                        weight: FontWeight.w800,
                        color: accent ? Colors.white : AppColors.ink)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: jakarta(12,
                        height: 1.35,
                        color: accent
                            ? AppColors.white(.72)
                            : AppColors.muted)),
              ],
            ),
          ),
          Sym(Symbols.chevron_right_rounded,
              color: accent ? AppColors.white(.6) : AppColors.muted),
        ]),
      ),
    );
  }
}
