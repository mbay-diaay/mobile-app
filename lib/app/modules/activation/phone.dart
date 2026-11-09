import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import "package:flutter/foundation.dart";

/// 01 · Activation · e-mail et mot de passe (puis code OTP à l'étape 02).
/// Forme d'adresse simple ; `GetUtils.isEmail` refuse les domaines de plus de 5 lettres (« .example »).
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

class PhoneController extends GetxController {
  final email = TextEditingController();
  final password = TextEditingController();
  final emailFocus = FocusNode();
  final passFocus = FocusNode();
  final hidden = true.obs;
  final emailText = ''.obs;
  final passText = ''.obs;
  final error = RxnString();
  final shake = 0.obs;

  bool get valid =>
      _emailRe.hasMatch(emailText.value.trim()) && passText.value.length >= 8;

  void onChanged() {
    emailText.value = email.text;
    passText.value = password.text;
    error.value = null;
  }

  Future<void> submit() async {
    if (!valid) return;
    emailFocus.unfocus();
    passFocus.unfocus();
    try {
      final challenge = await Get.find<AuthService>()
          .signIn(email: email.text, password: password.text);
      Get.toNamed(Routes.smsCode, arguments: challenge);
    } on ApiException catch (e) {
      debugPrint("[ERROR][Phone.submit] ${e}");
      error.value = e.userMessage;
      shake.value++;
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    emailFocus.dispose();
    passFocus.dispose();
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
                      child: IconTile(Symbols.mail_rounded,
                          size: 56, radius: 18, iconSize: 30, fill: true),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: Text('Connexion à votre compte',
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
                      const _FieldLabel('E-MAIL'),
                      const SizedBox(height: 10),
                      Obx(() => Shake(
                          trigger: controller.shake.value,
                          child: _Field(
                            controller: controller.email,
                            focus: controller.emailFocus,
                            hint: 'prenom.nom@cradesc.example',
                            icon: Symbols.alternate_email_rounded,
                            keyboard: TextInputType.emailAddress,
                            onChanged: controller.onChanged,
                            onSubmitted: controller.passFocus.requestFocus,
                          ))),
                      const SizedBox(height: 16),
                      const _FieldLabel('MOT DE PASSE'),
                      const SizedBox(height: 10),
                      Obx(() => _Field(
                            controller: controller.password,
                            focus: controller.passFocus,
                            hint: '8 caractères minimum',
                            icon: Symbols.lock_rounded,
                            obscure: controller.hidden.value,
                            onChanged: controller.onChanged,
                            onSubmitted: controller.submit,
                            trailing: GestureDetector(
                              onTap: controller.hidden.toggle,
                              child: Sym(
                                  controller.hidden.value
                                      ? Symbols.visibility_rounded
                                      : Symbols.visibility_off_rounded,
                                  size: 22,
                                  color: AppColors.muted),
                            ),
                          )),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 500),
                        child: Obx(() {
                          final msg = controller.error.value;
                          final bad = msg != null;
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
                                      : Symbols.mark_email_read_rounded,
                                  size: 20,
                                  color: bad
                                      ? AppColors.redInk
                                      : AppColors.forest),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  msg ??
                                      'Un code de vérification arrive par e-mail.',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: jakarta(11,
          weight: FontWeight.w700, tracking: .06, color: AppColors.muted));
}

/// Champ de saisie arrondi, bordure verte et halo citron au focus.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.icon,
    required this.onChanged,
    required this.onSubmitted,
    this.keyboard,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final IconData icon;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focus,
      builder: (_, __) => AnimatedContainer(
        duration: Motion.medium,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.forest, width: 2),
          boxShadow: focus.hasFocus
              ? [
                  BoxShadow(
                      color: AppColors.lime.withValues(alpha: .7),
                      spreadRadius: 4)
                ]
              : const [],
        ),
        child: Row(children: [
          Sym(icon, size: 22, color: AppColors.forest),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              keyboardType: keyboard,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction:
                  obscure ? TextInputAction.done : TextInputAction.next,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmitted(),
              style: jakarta(16, weight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: jakarta(15,
                    weight: FontWeight.w600, color: AppColors.faint),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
