import 'dart:async';

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

/// 02 · Activation · code OTP reçu par e-mail (vérifié par l'API).
class SmsCodeController extends GetxController {
  final text = TextEditingController();
  final focus = FocusNode();
  final code = ''.obs;
  final resendIn = 30.obs;
  final error = RxnString();
  final shake = 0.obs;
  Timer? _timer;

  late SignInChallenge challenge = (Get.arguments is SignInChallenge)
      ? Get.arguments as SignInChallenge
      : const SignInChallenge(id: '', maskedEmail: '', resendAvailableAt: 0);
  String get masked => challenge.maskedEmail;

  @override
  void onInit() {
    super.onInit();
    _startTimer(challenge.resendWaitSeconds);
  }

  @override
  void onReady() {
    super.onReady();
    Future.delayed(const Duration(milliseconds: 600), focus.requestFocus);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    resendIn.value = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendIn.value <= 1) t.cancel();
      resendIn.value--;
    });
  }

  Future<void> resend() async {
    if (resendIn.value > 0) return;
    try {
      challenge = await Get.find<AuthService>().resendOtp(challenge);
      _startTimer(challenge.resendWaitSeconds);
      showToast('Nouveau code envoyé à $masked', icon: Symbols.mail_rounded);
    } on ApiException catch (e) {
      showToast(e.userMessage, icon: Symbols.error_rounded);
    }
  }

  void onChanged(String v) {
    code.value = v;
    error.value = null;
    // Code complet : on range le clavier pour dévoiler le CTA à glisser.
    if (v.length == 6) focus.unfocus();
  }

  Future<void> validate() async {
    if (code.value.length != 6) return;
    focus.unfocus();
    try {
      final auth = Get.find<AuthService>();
      await auth.verifyOtp(challengeId: challenge.id, code: code.value);
      final me = await auth.me();
      final session = Get.find<SessionService>();
      session.signIn(TestAccount.fromUser(me, scoop: me.scoopName ?? ''));
      Get.toNamed(Routes.pinCreate);
    } on ApiException catch (e) {
      error.value = e.userMessage;
      shake.value++;
      text.clear();
      code.value = '';
      focus.requestFocus();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    text.dispose();
    focus.dispose();
    super.onClose();
  }
}

class SmsCodeView extends GetView<SmsCodeController> {
  const SmsCodeView({super.key});

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
                    FadeSlideIn(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SquareIconButton.onDark(onTap: Get.back),
                            const StepLabel(2),
                            const StepIndicator(step: 2),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: Text('Code de vérification',
                          style: display(30, color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Text.rich(TextSpan(
                        style: jakarta(13, color: AppColors.white(.7)),
                        children: [
                          const TextSpan(text: 'Envoyé à '),
                          TextSpan(
                              text: controller.masked,
                              style: jakarta(13,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      )),
                    ),
                  ]),
            ),
          ),
          Expanded(
            child: RisingSheet(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: FillScroll(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Obx(() => Shake(
                          trigger: controller.shake.value,
                          child: _CodeBoxes(controller: controller))),
                      Obx(() {
                        final msg = controller.error.value;
                        if (msg == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(msg,
                              style: jakarta(13,
                                  weight: FontWeight.w700,
                                  color: AppColors.redInk)),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pas reçu ?',
                                style: jakarta(13, color: AppColors.muted)),
                            Obx(() {
                              final wait = controller.resendIn.value;
                              return GestureDetector(
                                onTap: controller.resend,
                                child: AnimatedOpacity(
                                  duration: Motion.fast,
                                  opacity: wait > 0 ? .5 : 1,
                                  child: Row(children: [
                                    const Sym(Symbols.refresh_rounded,
                                        size: 18, color: AppColors.forest),
                                    const SizedBox(width: 6),
                                    Text(
                                        wait > 0
                                            ? 'Renvoyer dans ${wait}s'
                                            : 'Renvoyer le code',
                                        style: jakarta(13,
                                            weight: FontWeight.w700,
                                            color: AppColors.forest)),
                                  ]),
                                ),
                              );
                            }),
                          ]),
                      const Spacer(),
                      const SizedBox(height: 16),
                      Obx(() => SwipeCta.dark(
                            label: 'Glissez pour valider',
                            busyLabel: 'Vérification…',
                            onConfirm: controller.code.value.length == 6
                                ? controller.validate
                                : null,
                          )),
                    ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Six cases ; un champ invisible capte la saisie, la case courante est surlignée.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller});
  final SmsCodeController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.focus.requestFocus,
      child: Stack(children: [
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 58,
            child: TextField(
              controller: controller.text,
              focusNode: controller.focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)
              ],
              onChanged: controller.onChanged,
              showCursor: false,
            ),
          ),
        ),
        Obx(() {
          final code = controller.code.value;
          return Row(children: [
            for (var i = 0; i < 6; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: FadeSlideIn(
                  delay: Motion.stagger(i, step: 50, base: 350),
                  offset: const Offset(0, 20),
                  child: _Box(
                      char: i < code.length ? code[i] : null,
                      active: i == code.length),
                ),
              ),
            ],
          ]);
        }),
      ]),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.char, required this.active});
  final String? char;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.spring,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppColors.forest : Colors.transparent,
              width: 2.5),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.lime.withValues(alpha: .7),
                      spreadRadius: 4)
                ]
              : const [],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: (c, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
              child: c),
          child: char != null
              ? Text(char!,
                  key: ValueKey(char),
                  style: jakarta(26, weight: FontWeight.w800))
              : active
                  ? const _Caret()
                  : Text('•', style: jakarta(24, color: AppColors.faint)),
        ),
      );
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _c,
      child: Container(width: 2, height: 24, color: AppColors.forest));
}
