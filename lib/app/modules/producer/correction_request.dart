import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// Demande de correction (MO-61) : champs non sensibles ou demande d’identité.
class CorrectionRequestController extends GetxController {
  late final Producer producer;
  final field = 'Téléphone'.obs;
  final detail = TextEditingController();
  final shake = 0.obs;

  static const fields = [
    'Téléphone',
    'Village',
    'Organisation',
    'Âge',
    'Identité (CNI / nom)',
  ];

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is Producer) {
      producer = arg;
    } else if (arg is AuthUser) {
      final name = arg.name.trim().isEmpty ? 'Votre fiche' : arg.name.trim();
      final parts = name.split(RegExp(r'\s+'));
      final initials = parts.length >= 2
          ? '${parts.first[0]}${parts.last[0]}'
          : name[0];
      producer = Producer(
        initials: initials.toUpperCase(),
        name: name,
        village: '—',
        age: 0,
        tint: AppColors.sage,
        code: arg.id.isEmpty ? 'LOCAL' : arg.id,
        phone: '—',
        sex: '—',
        org: '—',
      );
    } else {
      // Écran ouvert seul (dev) : premier mock, jamais en prod producteur.
      producer = MockData.producers.isNotEmpty
          ? MockData.producers.first
          : const Producer(
              initials: '—',
              name: 'Votre fiche',
              village: '—',
              age: 0,
              tint: AppColors.sage,
              code: 'LOCAL',
              phone: '—',
              sex: '—',
              org: '—',
            );
    }
  }

  bool get valid => detail.text.trim().length >= 8;
  final busy = false.obs;
  final error = RxnString();

  Future<void> submit() async {
    if (!valid) {
      shake.value++;
      return;
    }
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    final to = detail.text.trim();
    final from = switch (field.value) {
      'Téléphone' => producer.phone,
      'Village' => producer.village,
      'Organisation' => producer.org,
      'Âge' => producer.age > 0 ? '${producer.age}' : '—',
      _ => '—',
    };
    try {
      await Get.find<SessionService>().submitCorrection(
        producer: producer,
        field: field.value,
        from: from,
        to: to,
        motif: 'Demande mobile · ${field.value}',
      );
      Get.offNamed(Routes.success, arguments: {
        'title': 'Demande envoyée',
        'sub':
            '${producer.name}\n${field.value} : $to\nSuivi par votre SCOOP / technicien.',
        'cta': "Retour à l'accueil",
      });
    } catch (e) {
      error.value = 'Demande enregistrée en local — envoi serveur impossible.';
      Get.offNamed(Routes.success, arguments: {
        'title': 'Demande enregistrée',
        'sub':
            '${producer.name}\n${field.value} : $to\nEn attente de synchro.',
        'cta': "Retour à l'accueil",
      });
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    detail.dispose();
    super.onClose();
  }
}

class CorrectionRequestView extends GetView<CorrectionRequestController> {
  const CorrectionRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: FillScroll(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  child: Row(children: [
                    SquareIconButton(onTap: Get.back),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text('Demander une correction', style: display(22))),
                  ]),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: Motion.stagger(1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      'Producteur · ${c.producer.name} (${c.producer.code})',
                      style: jakarta(13,
                          weight: FontWeight.w700, color: AppColors.blueInk),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: Motion.stagger(2),
                  child: Text('Champ concerné',
                      style: jakarta(14, weight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in CorrectionRequestController.fields)
                          Chip2(
                            label: f,
                            bg: c.field.value == f
                                ? AppColors.lime
                                : Colors.white,
                            fg: AppColors.forest,
                            onTap: () => c.field.value = f,
                          ),
                      ],
                    )),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: Motion.stagger(3),
                  child: Shake(
                    trigger: c.shake.value,
                    child: TextField(
                      controller: c.detail,
                      onChanged: (_) => c.field.refresh(),
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Précisez la correction',
                        hintText: 'Ex. le bon numéro est 77 123 45 67',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Obx(() => SwipeCta(
                      label: 'Glissez pour envoyer',
                      icon: Symbols.send_rounded,
                      onConfirm: c.valid ? c.submit : null,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
