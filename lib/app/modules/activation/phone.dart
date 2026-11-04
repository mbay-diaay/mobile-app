import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/senegal_flag.dart';

/// 01 · Activation · téléphone
class PhoneController extends GetxController {
  final text = TextEditingController(text: '77 123 45 67');
  final focus = FocusNode();
  final digits = '771234567'.obs;
  final sending = false.obs;
  final unknown = false.obs;
  final shake = 0.obs;

  bool get valid => digits.value.length == 9;

  void onChanged(String v) {
    digits.value = v.replaceAll(' ', '');
    unknown.value = false;
  }

  Future<void> submit() async {
    if (!valid || sending.value) return;
    focus.unfocus();
    sending.value = true;
    await Future.delayed(const Duration(milliseconds: 700));
    sending.value = false;
    // Connexion simulée : seuls les numéros de test sont reconnus.
    final account = Get.find<SessionService>().findAccount(digits.value);
    if (account == null) {
      unknown.value = true;
      shake.value++;
      return;
    }
    Get.find<SessionService>().signIn(account);
    Get.toNamed(Routes.smsCode, arguments: digits.value);
  }

  @override
  void onClose() {
    text.dispose();
    focus.dispose();
    super.onClose();
  }
}

class PhoneView extends GetView<PhoneController> {
  const PhoneView({super.key});

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
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [StepLabel(1), StepIndicator(step: 1)]),
                    ),
                    const SizedBox(height: 20),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 100),
                      scale: .4,
                      curve: Curves.elasticOut,
                      duration: Duration(milliseconds: 1100),
                      child: IconTile(Symbols.smartphone_rounded,
                          size: 56, radius: 18, iconSize: 30, fill: true),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: Text('Votre numéro de téléphone',
                          style: display(30, color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 240),
                      child: Text('Wolof · traduction à venir',
                          style: jakarta(12,
                              style: FontStyle.italic,
                              color: AppColors.white(.6))),
                    ),
                  ]),
            ),
          ),
          Expanded(
            child: RisingSheet(
              child: FillScroll(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('NUMÉRO',
                          style: jakarta(11,
                              weight: FontWeight.w700,
                              tracking: .06,
                              color: AppColors.muted)),
                      const SizedBox(height: 14),
                      Obx(() => Shake(
                          trigger: controller.shake.value,
                          child: _PhoneField(controller: controller))),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 500),
                        child: Obx(() {
                          final bad = controller.unknown.value;
                          return AnimatedContainer(
                            duration: Motion.medium,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                                color: bad ? AppColors.redSoft : AppColors.sage,
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              Sym(
                                  bad
                                      ? Symbols.error_rounded
                                      : Symbols.sms_rounded,
                                  size: 20,
                                  color: bad
                                      ? AppColors.redInk
                                      : AppColors.forest),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  bad
                                      ? "Ce numéro n'est pas enregistré pour votre SCOOP."
                                      : 'Un code arrive par SMS.',
                                  style: jakarta(13,
                                      color: bad
                                          ? AppColors.redInk
                                          : AppColors.inkSoft,
                                      weight: bad
                                          ? FontWeight.w700
                                          : FontWeight.w500),
                                ),
                              ),
                            ]),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      CustomPaint(
                        painter: DashedBorderPainter(
                            color: AppColors.faint, width: 1.5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Text(
                            'Prototype · numéros de test : '
                            '${SessionService.testAccounts.map((a) => '${a.phone.substring(0, 2)} ${a.phone.substring(2, 5)} ${a.phone.substring(5, 7)} ${a.phone.substring(7)} (${a.name})').join(' · ')}',
                            style: jakarta(11,
                                color: AppColors.muted, height: 1.4),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 600),
                        child: Obx(() => SwipeCta(
                              label: 'Glissez pour recevoir le code',
                              busyLabel: 'Envoi du code…',
                              onConfirm:
                                  controller.valid ? controller.submit : null,
                            )),
                      ),
                    ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.focus,
      builder: (_, __) => AnimatedContainer(
        duration: Motion.medium,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.forest, width: 2),
          boxShadow: controller.focus.hasFocus
              ? [
                  BoxShadow(
                      color: AppColors.lime.withValues(alpha: .7),
                      spreadRadius: 4)
                ]
              : const [],
        ),
        child: Row(children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: AppColors.sage, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const SenegalFlag(),
              const SizedBox(width: 6),
              Text('+221', style: jakarta(15, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller.text,
              focusNode: controller.focus,
              keyboardType: TextInputType.phone,
              onChanged: controller.onChanged,
              onSubmitted: (_) => controller.submit(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
                _SnPhoneFormatter()
              ],
              style: jakarta(21, weight: FontWeight.w700, tracking: .02),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '77 123 45 67',
                hintStyle: jakarta(21,
                    weight: FontWeight.w700, color: AppColors.faint),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// « 771234567 » → « 77 123 45 67 ».
class _SnPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(' ', '');
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 7) b.write(' ');
      b.write(d[i]);
    }
    final s = b.toString();
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
