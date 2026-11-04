import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import 'buttons.dart';

/// Fiche de confirmation qui monte du bas. Renvoie `true` si l'utilisateur confirme.
/// [destructive] colore le bouton en rouge (perte de données).
Future<bool> confirmSheet({
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
  IconData icon = Symbols.help_rounded,
  bool destructive = false,
}) async {
  final r = await Get.bottomSheet<bool>(
    _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: destructive,
    ),
    barrierColor: const Color(0x8C0A140F),
    enterBottomSheetDuration: const Duration(milliseconds: 380),
  );
  return r ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconTile(
                  icon,
                  bg: destructive ? AppColors.redSoft : AppColors.amberSoft,
                  fg: destructive ? AppColors.redInk : AppColors.amberInk,
                  iconSize: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: jakarta(18,
                                weight: FontWeight.w800,
                                tracking: -.02,
                                height: 1.2)),
                        const SizedBox(height: 6),
                        Text(message,
                            style: jakarta(13,
                                color: AppColors.muted, height: 1.45)),
                      ]),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: FlatButton(
                        label: cancelLabel,
                        height: 52,
                        radius: 16,
                        onTap: () => Get.back(result: false))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FlatButton(
                    label: confirmLabel,
                    bg: destructive ? AppColors.redDark : AppColors.forest,
                    fg: Colors.white,
                    height: 52,
                    radius: 16,
                    weight: FontWeight.w800,
                    onTap: () => Get.back(result: true),
                  ),
                ),
              ]),
            ]),
      );
}
