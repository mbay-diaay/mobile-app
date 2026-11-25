import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

class ProducerRegisterController extends GetxController {
  final phone = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final invite = TextEditingController();
  final hidden = true.obs;
  final busy = false.obs;
  final error = RxnString();
  final shake = 0.obs;
  final rev = 0.obs;

  final _phoneRe = RegExp(r'^\+?[\d\s.-]{9,20}$');
  bool _strong(String v) =>
      v.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(v) &&
      RegExp(r'\d').hasMatch(v);

  bool get valid {
    rev.value;
    return _phoneRe.hasMatch(phone.text.trim()) &&
        first.text.trim().isNotEmpty &&
        last.text.trim().isNotEmpty &&
        _strong(password.text) &&
        confirm.text == password.text;
  }

  void touch() {
    rev.value++;
    error.value = null;
  }

  Future<void> submit() async {
    if (!valid || busy.value) return;
    busy.value = true;
    error.value = null;
    try {
      final auth = Get.find<AuthService>();
      final user = await auth.registerProducer(
        phone: phone.text,
        password: password.text,
        firstName: first.text,
        lastName: last.text,
        invitationCode: invite.text,
      );
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
      final resolved = me.name.isEmpty ? user : me;
      await session.saveProducerUser(resolved);
      Get.offAllNamed(Routes.producerHome, arguments: resolved);
    } on ApiException catch (e) {
      error.value = e.userMessage;
      shake.value++;
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    phone.dispose();
    first.dispose();
    last.dispose();
    password.dispose();
    confirm.dispose();
    invite.dispose();
    super.onClose();
  }
}

class ProducerRegisterView extends GetView<ProducerRegisterController> {
  const ProducerRegisterView({super.key});

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
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                    child: const IconTile(Symbols.person_add_rounded,
                        size: 56, radius: 18, iconSize: 30, fill: true),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('Créer mon compte',
                        style: display(28, color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
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
                        _label('TÉLÉPHONE *'),
                        const SizedBox(height: 8),
                        Shake(
                          trigger: c.shake.value,
                          child: _field(
                            c.phone,
                            '77 123 45 67',
                            Symbols.call_rounded,
                            keyboard: TextInputType.phone,
                            onChanged: (_) => c.touch(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('PRÉNOM *'),
                              const SizedBox(height: 8),
                              _field(c.first, null, Symbols.badge_rounded,
                                  onChanged: (_) => c.touch()),
                            ],
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('NOM *'),
                              const SizedBox(height: 8),
                              _field(c.last, null, Symbols.badge_rounded,
                                  onChanged: (_) => c.touch()),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 12),
                        _label('MOT DE PASSE *'),
                        const SizedBox(height: 8),
                        _field(
                          c.password,
                          '8 car. · lettre + chiffre',
                          Symbols.lock_rounded,
                          obscure: c.hidden.value,
                          onChanged: (_) => c.touch(),
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
                        const SizedBox(height: 12),
                        _label('CONFIRMER *'),
                        const SizedBox(height: 8),
                        _field(c.confirm, 'Retapez le mot de passe',
                            Symbols.lock_rounded,
                            obscure: true, onChanged: (_) => c.touch()),
                        const SizedBox(height: 12),
                        _label('CODE INVITATION SCOOP'),
                        const SizedBox(height: 8),
                        _field(c.invite, 'Facultatif', Symbols.vpn_key_rounded,
                            onChanged: (_) => c.touch()),
                        const SizedBox(height: 14),
                        _Banner(
                          message: c.error.value,
                          hint:
                              'Téléphone + mot de passe. Le code d’invitation SCOOP est facultatif.',
                        ),
                        const Spacer(),
                        FadeSlideIn(
                          delay: Motion.stagger(3),
                          child: SwipeCta(
                            label: 'Glissez pour créer mon compte',
                            busyLabel: 'Création…',
                            onConfirm:
                                c.valid && !c.busy.value ? c.submit : null,
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

  Widget _label(String t) => Text(t,
      style: jakarta(11,
          weight: FontWeight.w700, color: AppColors.muted, tracking: 0.08));

  Widget _field(
    TextEditingController ctl,
    String? hint,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    Widget? trailing,
    ValueChanged<String>? onChanged,
  }) {
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
            controller: ctl,
            keyboardType: keyboard,
            obscureText: obscure,
            onChanged: onChanged,
            style: jakarta(15, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: jakarta(14, color: AppColors.muted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (trailing != null) trailing,
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
