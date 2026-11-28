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
import 'phone.dart';

/// Nouveau compte vs déjà inscrit — oriente technicien et producteur.
enum AuthIntent { first, returning }

class AuthIntentController extends GetxController {
  late final AppRole role;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is AppRole) {
      role = args;
    } else if (args is Map && args['role'] is AppRole) {
      role = args['role'] as AppRole;
    } else {
      role = Get.find<SessionService>().appRole.value ?? AppRole.technician;
    }
  }

  Future<void> choose(AuthIntent intent) async {
    final session = Get.find<SessionService>();
    await session.setAppRole(role);
    if (role == AppRole.technician) {
      Get.toNamed(
        Routes.phone,
        arguments: {
          'mode': intent == AuthIntent.first
              ? LoginMode.first
              : LoginMode.password,
        },
      );
      return;
    }
    Get.toNamed(
      intent == AuthIntent.first
          ? Routes.producerRegister
          : Routes.producerLogin,
    );
  }

  Future<void> backToRole() async {
    await Get.find<SessionService>().clearAppRole();
    Get.offAllNamed(Routes.roleGate);
  }
}

class AuthIntentView extends GetView<AuthIntentController> {
  const AuthIntentView({super.key});

  @override
  Widget build(BuildContext context) {
    final isTech = controller.role == AppRole.technician;
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
                      onPressed: controller.backToRole,
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
                    child: IconTile(
                      isTech
                          ? Symbols.engineering_rounded
                          : Symbols.agriculture_rounded,
                      size: 56,
                      radius: 18,
                      iconSize: 30,
                      fill: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('intent.title'.tr,
                        style: display(30, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: Motion.stagger(2),
                    child: Text(
                      isTech ? 'intent.leadTech'.tr : 'intent.leadProd'.tr,
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
                      child: _IntentCard(
                        icon: Symbols.person_add_rounded,
                        title: 'intent.first'.tr,
                        subtitle: isTech
                            ? 'intent.firstTechSub'.tr
                            : 'intent.firstProdSub'.tr,
                        onTap: () =>
                            controller.choose(AuthIntent.first),
                        accent: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: Motion.stagger(3),
                      child: _IntentCard(
                        icon: Symbols.login_rounded,
                        title: 'intent.returning'.tr,
                        subtitle: isTech
                            ? 'intent.returningTechSub'.tr
                            : 'intent.returningProdSub'.tr,
                        onTap: () =>
                            controller.choose(AuthIntent.returning),
                      ),
                    ),
                    const Spacer(),
                    FadeSlideIn(
                      delay: Motion.stagger(4),
                      child: Text(
                        'intent.footer'.tr,
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

class _IntentCard extends StatelessWidget {
  const _IntentCard({
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
