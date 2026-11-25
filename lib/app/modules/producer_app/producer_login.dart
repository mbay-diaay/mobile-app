import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/producer_seed.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

class ProducerLoginController extends GetxController {
  final phone = TextEditingController(text: ProducerSeed.phoneDisplay);
  final password = TextEditingController(text: ProducerSeed.password);
  final phoneFocus = FocusNode();
  final passFocus = FocusNode();
  final hidden = true.obs;
  final busy = false.obs;
  final error = RxnString();
  final shake = 0.obs;
  final rev = 0.obs;

  final _phoneRe = RegExp(r'^\+?[\d\s.-]{9,20}$');

  bool get valid {
    rev.value;
    return _phoneRe.hasMatch(phone.text.trim()) && password.text.length >= 8;
  }

  void touch() {
    rev.value++;
    error.value = null;
  }

  Future<void> enterSeed() async {
    phone.text = ProducerSeed.phoneDisplay;
    password.text = ProducerSeed.password;
    rev.value++;
    error.value = null;
    final session = Get.find<SessionService>();
    await session.setAppRole(AppRole.producer);
    await session.saveProducerUser(ProducerSeed.user);
    Get.offAllNamed(Routes.producerHome, arguments: ProducerSeed.user);
  }

  Future<void> submit() async {
    if (!valid || busy.value) return;
    busy.value = true;
    error.value = null;
    try {
      // Seed local : téléphone démo → pas d’API (même si le MDP a bougé un peu).
      if (ProducerSeed.isSeedPhone(phone.text)) {
        if (!ProducerSeed.matches(
            phone: phone.text, password: password.text)) {
          error.value =
              'Mot de passe seed : ${ProducerSeed.password}';
          shake.value++;
          return;
        }
        await Get.find<SessionService>().setAppRole(AppRole.producer);
        Get.offAllNamed(Routes.producerHome, arguments: ProducerSeed.user);
        return;
      }
      final auth = Get.find<AuthService>();
      final user =
          await auth.signInProducer(phone: phone.text, password: password.text);
      AuthUser me = user;
      final api = Get.find<ApiClient>();
      if (!api.isLocalSession) {
        try {
          me = await auth.me();
        } catch (_) {}
      }
      if (me.role.isNotEmpty && me.role != AuthUser.producerRole) {
        await auth.logout();
        error.value = 'Ce compte n’est pas un compte producteur.';
        shake.value++;
        return;
      }
      final session = Get.find<SessionService>();
      await session.setAppRole(AppRole.producer);
      await session.saveProducerUser(me.name.isEmpty ? user : me);
      Get.offAllNamed(Routes.producerHome, arguments: me.name.isEmpty ? user : me);
    } on ApiException catch (e) {
      error.value = e.userMessage;
      shake.value++;
    } catch (e) {
      error.value =
          'Connexion impossible. Vérifiez le réseau et réessayez.';
      shake.value++;
      debugPrint('[ERROR][ProducerLogin.submit] $e');
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    phone.dispose();
    password.dispose();
    phoneFocus.dispose();
    passFocus.dispose();
    super.onClose();
  }
}

class ProducerLoginView extends GetView<ProducerLoginController> {
  const ProducerLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
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
                    child: IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Symbols.arrow_back_rounded,
                          color: Colors.white),
                    ),
                  ),
                  FadeSlideIn(
                    delay: Motion.stagger(0),
                    child: const IconTile(Symbols.login_rounded,
                        size: 56, radius: 18, iconSize: 30, fill: true),
                  ),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('Connexion',
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
                child: Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('TÉLÉPHONE',
                            style: jakarta(11,
                                weight: FontWeight.w700,
                                color: AppColors.muted,
                                tracking: 0.08)),
                        const SizedBox(height: 10),
                        Shake(
                          trigger: c.shake.value,
                          child: _Field(
                            controller: c.phone,
                            focus: c.phoneFocus,
                            hint: '77 123 45 67',
                            icon: Symbols.call_rounded,
                            keyboard: TextInputType.phone,
                            onChanged: (_) => c.touch(),
                            onSubmitted: c.passFocus.requestFocus,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('MOT DE PASSE',
                            style: jakarta(11,
                                weight: FontWeight.w700,
                                color: AppColors.muted,
                                tracking: 0.08)),
                        const SizedBox(height: 10),
                        _Field(
                          controller: c.password,
                          focus: c.passFocus,
                          hint: '8 caractères minimum',
                          icon: Symbols.lock_rounded,
                          obscure: c.hidden.value,
                          onChanged: (_) => c.touch(),
                          onSubmitted: c.submit,
                          trailing: GestureDetector(
                            onTap: c.hidden.toggle,
                            child: Sym(
                                c.hidden.value
                                    ? Symbols.visibility_rounded
                                    : Symbols.visibility_off_rounded,
                                size: 22,
                                color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Banner(
                          message: c.error.value,
                          hint: 'auth.prod.hintLogin'.tr,
                        ),
                        if (!kReleaseMode) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: c.busy.value ? null : c.enterSeed,
                              child: Text(
                                'auth.prod.seed'.tr,
                                textAlign: TextAlign.center,
                                style: jakarta(13,
                                    weight: FontWeight.w800,
                                    color: AppColors.forest),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        FadeSlideIn(
                          delay: Motion.stagger(3),
                          child: SwipeCta(
                            label: 'Glissez pour vous connecter',
                            busyLabel: 'Connexion…',
                            onConfirm: c.valid && !c.busy.value
                                ? c.submit
                                : null,
                          ),
                        ),
                      ],
                    )),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(children: [
        Sym(icon, size: 22, color: AppColors.forest),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            obscureText: obscure,
            keyboardType: keyboard,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted?.call(),
            style: jakarta(15, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: jakarta(14, color: AppColors.muted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.hint});
  final String? message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final bad = message != null;
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bad ? AppColors.redSoft : AppColors.sage,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Sym(bad ? Symbols.error_rounded : Symbols.info_rounded,
            size: 20, color: bad ? AppColors.redInk : AppColors.forest),
        const SizedBox(width: 10),
        Expanded(
          child: Text(bad ? message! : hint,
              style: jakarta(12,
                  weight: FontWeight.w600,
                  color: bad ? AppColors.redInk : AppColors.forest,
                  height: 1.35)),
        ),
      ]),
    );
  }
}
