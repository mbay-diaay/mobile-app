import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// Saisie rapide d’une charge (PRD §3.8).
class QuickExpenseController extends GetxController {
  final producers = Get.find<SessionService>().activeProducers;
  final producer = Rxn<Producer>();
  final category = 'Intrants'.obs;
  final amount = TextEditingController();
  final note = TextEditingController();
  final shake = 0.obs;

  static const categories = [
    'Intrants',
    'Main-d’œuvre',
    'Transport',
    'Irrigation',
    'Location matériel',
    'Autre',
  ];

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is Producer) producer.value = arg;
  }

  bool get valid =>
      producer.value != null &&
      (double.tryParse(amount.text.replaceAll(',', '.').replaceAll(' ', '')) ??
              0) >
          0;

  void save() {
    if (!valid) {
      shake.value++;
      return;
    }
    final p = producer.value!;
    final label =
        'Charge · ${p.name} · ${category.value} · ${amount.text} FCFA';
    Get.find<SessionService>()
        .queueCommerce(Symbols.payments_rounded, label);
    Get.offNamed(Routes.success, arguments: {
      'title': 'Charge enregistrée',
      'sub':
          '$label\nÉcriture non modifiable : correction par contre-écriture seulement.',
      'cta': "Retour à l'accueil",
    });
  }

  @override
  void onClose() {
    amount.dispose();
    note.dispose();
    super.onClose();
  }
}

class QuickExpenseView extends GetView<QuickExpenseController> {
  const QuickExpenseView({super.key});

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
                        child: Text('Nouvelle charge', style: display(22))),
                  ]),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: Motion.stagger(1),
                  child: Text('Producteur, catégorie, montant.',
                      style: jakarta(12, color: AppColors.muted)),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: Motion.stagger(2),
                  child: Obx(() => DropdownButtonFormField<Producer>(
                        value: c.producer.value,
                        decoration: _dec('Producteur *'),
                        items: [
                          for (final p in c.producers)
                            DropdownMenuItem(value: p, child: Text(p.name)),
                        ],
                        onChanged: (p) => c.producer.value = p,
                      )),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: Motion.stagger(3),
                  child: Obx(() => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat
                              in QuickExpenseController.categories)
                            Chip2(
                              label: cat,
                              bg: c.category.value == cat
                                  ? AppColors.lime
                                  : Colors.white,
                              fg: AppColors.forest,
                              onTap: () => c.category.value = cat,
                            ),
                        ],
                      )),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: Motion.stagger(4),
                  child: Shake(
                    trigger: c.shake.value,
                    child: TextField(
                      controller: c.amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      onChanged: (_) => c.producer.refresh(),
                      decoration: _dec('Montant (FCFA) *'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: Motion.stagger(5),
                  child: TextField(
                    controller: c.note,
                    maxLines: 2,
                    decoration: _dec('Note (facultatif)'),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Obx(() => SwipeCta(
                      label: 'Glissez pour enregistrer',
                      icon: Symbols.payments_rounded,
                      onConfirm: c.valid ? c.save : null,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      );
}
