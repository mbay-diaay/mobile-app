import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../routes/app_routes.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// 25 · Téléphone désactivé par l'administrateur.
class RevokedView extends StatelessWidget {
  const RevokedView({super.key});

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
                  duration: Duration(milliseconds: 1300),
                  child: Stack(alignment: Alignment.center, children: [
                    Breathing(
                      amount: .12,
                      period: Duration(milliseconds: 1400),
                      child: CircleAvatar(
                          radius: 60, backgroundColor: Color(0x1FFF6B6B)),
                    ),
                    IconTile(Symbols.mobile_off_rounded,
                        size: 84,
                        radius: 28,
                        iconSize: 42,
                        bg: AppColors.coral,
                        fg: AppColors.maroon,
                        fill: true),
                  ]),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Text('Téléphone désactivé',
                      textAlign: TextAlign.center,
                      style: display(30, color: Colors.white, height: 1.1)),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Text("L'administrateur a désactivé ce téléphone.",
                      textAlign: TextAlign.center,
                      style: jakarta(14,
                          color: AppColors.white(.75), height: 1.5)),
                ),
                const SizedBox(height: 18),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 300),
                  offset: Offset(-40, 0),
                  child: _Notice(
                    icon: Symbols.delete_forever_rounded,
                    bg: Color(0x2EFF6B6B),
                    fg: AppColors.coral,
                    text: 'Les données enregistrées dessus ont été effacées.',
                  ),
                ),
                const SizedBox(height: 8),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 380),
                  offset: Offset(40, 0),
                  child: _Notice(
                    icon: Symbols.support_agent_rounded,
                    bg: Color(0x26C6F05A),
                    fg: AppColors.lime,
                    text:
                        "Pour l'utiliser à nouveau, contactez votre gestionnaire de SCOOP.",
                  ),
                ),
                const Spacer(),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: SwipeCta(
                    label: 'Glissez pour réactiver',
                    onConfirm: () => Get.offAllNamed(Routes.phone),
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

class _Notice extends StatelessWidget {
  const _Notice(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.text});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.white(.07),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          IconTile(icon, size: 36, radius: 12, bg: bg, fg: fg, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: jakarta(13, color: Colors.white, height: 1.4))),
        ]),
      );
}
