import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import "package:flutter/foundation.dart";

/// 01 · Activation · connexion du technicien.
/// - `first` : première connexion = téléphone + code à 5 chiffres + mot de passe à choisir.
/// - `password` : téléphone + mot de passe (aucun code par e-mail).
/// - `email` : ancien parcours de test (e-mail + mot de passe, puis code à l'étape 02).
enum LoginMode { first, password, email }

/// Formes acceptées par l'API (mêmes règles côté serveur).
final _phoneRe = RegExp(r'^\+?[\d\s.-]{9,20}$');
final _codeRe = RegExp(r'^\d{5}$');

/// Forme d'adresse simple ; `GetUtils.isEmail` refuse les domaines de plus de 5 lettres (« .example »).
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Mot de passe : 8 caractères au moins, une lettre et un chiffre.
bool _isStrongPassword(String value) =>
    value.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(value) &&
    RegExp(r'\d').hasMatch(value);

class PhoneController extends GetxController {
  final mode = LoginMode.first.obs;

  /// Session expirée : reconnexion par mot de passe, les données du téléphone sont gardées.
  bool reconnect = false;

  final phone = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final email = TextEditingController();
  final phoneFocus = FocusNode();
  final codeFocus = FocusNode();
  final passFocus = FocusNode();
  final confirmFocus = FocusNode();
  final emailFocus = FocusNode();
  final hidden = true.obs;

  /// Incrémenté à chaque frappe pour recalculer [valid].
  final revision = 0.obs;
  final error = RxnString();
  final shake = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['reconnect'] == true) {
      reconnect = true;
      mode.value = LoginMode.password;
      error.value = 'Votre session a expiré. Reconnectez-vous.';
    }
  }

  bool get valid {
    revision.value;
    switch (mode.value) {
      case LoginMode.first:
        return _phoneRe.hasMatch(phone.text.trim()) &&
            _codeRe.hasMatch(code.text) &&
            _isStrongPassword(password.text) &&
            confirm.text == password.text;
      case LoginMode.password:
        return _phoneRe.hasMatch(phone.text.trim()) && password.text.length >= 8;
      case LoginMode.email:
        return _emailRe.hasMatch(email.text.trim()) && password.text.length >= 8;
    }
  }

  void setMode(LoginMode next) {
    if (mode.value == next) return;
    mode.value = next;
    error.value = null;
    revision.value++;
  }

  void onChanged() {
    revision.value++;
    error.value = null;
  }

  void _unfocusAll() {
    for (final node in [phoneFocus, codeFocus, passFocus, confirmFocus, emailFocus]) {
      node.unfocus();
    }
  }

  void _fail(String message) {
    error.value = message;
    shake.value++;
  }

  Future<void> submit() async {
    if (!valid) return;
    _unfocusAll();
    final auth = Get.find<AuthService>();
    try {
      if (mode.value == LoginMode.email) {
        final challenge =
            await auth.signIn(email: email.text, password: password.text);
        Get.toNamed(Routes.smsCode, arguments: challenge);
        return;
      }
      final user = mode.value == LoginMode.first
          ? await auth.activateTechnician(
              phone: phone.text, code: code.text, password: password.text)
          : await auth.signInTechnician(
              phone: phone.text, password: password.text);
      await _finish(auth, user);
    } on ApiException catch (e) {
      debugPrint("[ERROR][Phone.submit] ${e}");
      _fail(e.userMessage);
    }
  }

  /// Suite d'une connexion réussie : profil, contrôle du rôle, puis PIN ou retour à l'accueil.
  Future<void> _finish(AuthService auth, AuthUser fromLogin) async {
    final me = await auth.me();
    if (me.role != AuthUser.technicianRole) {
      await Get.find<ApiClient>().clearTokens();
      _fail('Cette application est réservée aux techniciens.');
      return;
    }
    final session = Get.find<SessionService>();
    if (reconnect) {
      if (session.activated.value && me.email == session.account.value.email) {
        await session.refreshMe();
        Get.offAllNamed(Routes.shell);
        return;
      }
      // Autre technicien : on ferme sa session et on vide le téléphone avant tout nouvel accès.
      await auth.logout();
      session.revoke();
      reconnect = false;
      password.clear();
      revision.value++;
      _fail(
          "Ce téléphone était utilisé par un autre compte : il a été réinitialisé. Reconnectez-vous.");
      return;
    }
    session.signIn(TestAccount.fromUser(me, scoop: me.scoopName ?? ''),
        permissions: me.permissions);
    Get.toNamed(Routes.pinCreate);
  }

  @override
  void onClose() {
    phone.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    email.dispose();
    phoneFocus.dispose();
    codeFocus.dispose();
    passFocus.dispose();
    confirmFocus.dispose();
    emailFocus.dispose();
    super.onClose();
  }
}

class PhoneView extends GetView<PhoneController> {
  const PhoneView({super.key});

  String _title(LoginMode mode) {
    if (controller.reconnect) return 'Reconnexion';
    return switch (mode) {
      LoginMode.first => 'Première connexion',
      LoginMode.password => 'Connexion à votre compte',
      LoginMode.email => 'Compte e-mail (test)',
    };
  }

  String _hint(LoginMode mode) => switch (mode) {
        LoginMode.first =>
          'Le code à 5 chiffres vous est remis par votre gestionnaire. Il ne sert qu\'une fois.',
        LoginMode.password => 'Utilisez le mot de passe choisi à votre première connexion.',
        LoginMode.email => 'Un code de vérification arrive par e-mail.',
      };

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
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      scale: .4,
                      curve: Curves.elasticOut,
                      duration: const Duration(milliseconds: 1100),
                      child: Obx(() => IconTile(
                          controller.mode.value == LoginMode.email
                              ? Symbols.mail_rounded
                              : Symbols.call_rounded,
                          size: 56,
                          radius: 18,
                          iconSize: 30,
                          fill: true)),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: Obx(() => Text(_title(controller.mode.value),
                          style: display(30, color: Colors.white))),
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
                child: Obx(() {
                  final mode = controller.mode.value;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!controller.reconnect && mode != LoginMode.email) ...[
                          _ModeSwitch(controller: controller),
                          const SizedBox(height: 18),
                        ],
                        if (mode == LoginMode.email) ...[
                          const _FieldLabel('E-MAIL'),
                          const SizedBox(height: 10),
                          Shake(
                              trigger: controller.shake.value,
                              child: _Field(
                                controller: controller.email,
                                focus: controller.emailFocus,
                                hint: 'prenom.nom@cradesc.example',
                                icon: Symbols.alternate_email_rounded,
                                keyboard: TextInputType.emailAddress,
                                onChanged: controller.onChanged,
                                onSubmitted: controller.passFocus.requestFocus,
                              )),
                        ] else ...[
                          const _FieldLabel('TÉLÉPHONE'),
                          const SizedBox(height: 10),
                          Shake(
                              trigger: controller.shake.value,
                              child: _Field(
                                controller: controller.phone,
                                focus: controller.phoneFocus,
                                hint: '77 123 45 67',
                                icon: Symbols.call_rounded,
                                keyboard: TextInputType.phone,
                                onChanged: controller.onChanged,
                                onSubmitted: () => (mode == LoginMode.first
                                        ? controller.codeFocus
                                        : controller.passFocus)
                                    .requestFocus(),
                              )),
                        ],
                        if (mode == LoginMode.first) ...[
                          const SizedBox(height: 16),
                          const _FieldLabel('CODE À 5 CHIFFRES'),
                          const SizedBox(height: 10),
                          _Field(
                            controller: controller.code,
                            focus: controller.codeFocus,
                            hint: '12345',
                            icon: Symbols.pin_rounded,
                            keyboard: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            onChanged: controller.onChanged,
                            onSubmitted: controller.passFocus.requestFocus,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _FieldLabel(mode == LoginMode.first
                            ? 'NOUVEAU MOT DE PASSE'
                            : 'MOT DE PASSE'),
                        const SizedBox(height: 10),
                        _Field(
                          controller: controller.password,
                          focus: controller.passFocus,
                          hint: mode == LoginMode.first
                              ? '8 caractères, une lettre et un chiffre'
                              : '8 caractères minimum',
                          icon: Symbols.lock_rounded,
                          obscure: controller.hidden.value,
                          onChanged: controller.onChanged,
                          onSubmitted: mode == LoginMode.first
                              ? controller.confirmFocus.requestFocus
                              : controller.submit,
                          trailing: GestureDetector(
                            onTap: controller.hidden.toggle,
                            child: Sym(
                                controller.hidden.value
                                    ? Symbols.visibility_rounded
                                    : Symbols.visibility_off_rounded,
                                size: 22,
                                color: AppColors.muted),
                          ),
                        ),
                        if (mode == LoginMode.first) ...[
                          const SizedBox(height: 16),
                          const _FieldLabel('CONFIRMER LE MOT DE PASSE'),
                          const SizedBox(height: 10),
                          _Field(
                            controller: controller.confirm,
                            focus: controller.confirmFocus,
                            hint: 'Retapez le mot de passe',
                            icon: Symbols.lock_rounded,
                            obscure: controller.hidden.value,
                            onChanged: controller.onChanged,
                            onSubmitted: controller.submit,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _Banner(
                            message: controller.error.value,
                            hint: _hint(mode)),
                        const Spacer(),
                        if (!controller.reconnect)
                          Center(
                            child: TextButton(
                              onPressed: () => controller.setMode(
                                  mode == LoginMode.email
                                      ? LoginMode.password
                                      : LoginMode.email),
                              child: Text(
                                  mode == LoginMode.email
                                      ? 'Connexion par téléphone'
                                      : 'Compte e-mail (test)',
                                  style: jakarta(12,
                                      weight: FontWeight.w600,
                                      color: AppColors.muted)),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 600),
                          child: SwipeCta(
                            label: switch (mode) {
                              LoginMode.first => 'Glissez pour activer',
                              LoginMode.password => 'Glissez pour vous connecter',
                              LoginMode.email => 'Glissez pour recevoir le code',
                            },
                            busyLabel: mode == LoginMode.email
                                ? 'Envoi du code…'
                                : 'Connexion…',
                            onConfirm: controller.valid ? controller.submit : null,
                          ),
                        ),
                      ]);
                }),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Choix entre première connexion (code) et connexion habituelle (mot de passe).
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.controller});
  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, LoginMode value) {
      final selected = controller.mode.value == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => controller.setMode(value),
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: selected ? AppColors.forest : Colors.transparent,
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(label,
                style: jakarta(13,
                    weight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.forest)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.sage, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        option('Première connexion', LoginMode.first),
        option('J\'ai un mot de passe', LoginMode.password),
      ]),
    );
  }
}

/// Message d'erreur (rouge) ou d'aide (vert pâle).
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
          child: Text(message ?? hint,
              style: jakarta(13,
                  color: bad ? AppColors.redInk : AppColors.inkSoft,
                  weight: bad ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]),
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
    this.formatters,
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
  final List<TextInputFormatter>? formatters;
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
              inputFormatters: formatters,
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
