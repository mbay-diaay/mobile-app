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

/// Saisie rapide d’une vente (PRD §3.8) — trois actions max.
class QuickSaleController extends GetxController {
  final producers = Get.find<SessionService>().activeProducers;
  final producer = Rxn<Producer>();
  final product = TextEditingController();
  final qty = TextEditingController();
  final price = TextEditingController();
  final destination = 'Vente'.obs;
  final shake = 0.obs;

  static const destinations = [
    'Vente',
    'Autoconsommation',
    'Transformation',
    'Perte',
  ];

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is Producer) producer.value = arg;
  }

  bool get valid =>
      producer.value != null &&
      product.text.trim().isNotEmpty &&
      (double.tryParse(qty.text.replaceAll(',', '.')) ?? 0) > 0;

  void save() {
    if (!valid) {
      shake.value++;
      return;
    }
    final p = producer.value!;
    final label =
        'Vente · ${p.name} · ${product.text.trim()} · ${qty.text} · ${destination.value}';
    Get.find<SessionService>()
        .queueCommerce(Symbols.shopping_bag_rounded, label);
    Get.offNamed(Routes.success, arguments: {
      'title': 'Vente enregistrée',
      'sub':
          '$label\nÉcriture non modifiable : une contre-écriture corrigera si besoin.',
      'cta': "Retour à l'accueil",
    });
  }

  @override
  void onClose() {
    product.dispose();
    qty.dispose();
    price.dispose();
    super.onClose();
  }
}

class QuickSaleView extends GetView<QuickSaleController> {
  const QuickSaleView({super.key});

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
                    Expanded(child: Text('Nouvelle vente', style: display(22))),
                  ]),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: Motion.stagger(1),
                  child: Text('Trois infos : producteur, produit, quantité.',
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
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: Motion.stagger(3),
                  child: Shake(
                    trigger: c.shake.value,
                    child: TextField(
                      controller: c.product,
                      onChanged: (_) => c.producer.refresh(),
                      decoration: _dec('Produit / culture *'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: Motion.stagger(4),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: c.qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => c.producer.refresh(),
                        decoration: _dec('Quantité *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: c.price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _dec('Prix (FCFA)'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: Motion.stagger(5),
                  child: Obx(() => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d
                              in QuickSaleController.destinations)
                            Chip2(
                              label: d,
                              bg: c.destination.value == d
                                  ? AppColors.lime
                                  : Colors.white,
                              fg: AppColors.forest,
                              onTap: () => c.destination.value = d,
                            ),
                        ],
                      )),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Obx(() => SwipeCta(
                      label: 'Glissez pour enregistrer',
                      icon: Symbols.shopping_bag_rounded,
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
