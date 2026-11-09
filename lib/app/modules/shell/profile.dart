import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart' show MockData;
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/layout.dart';
import 'shell.dart';

/// 24 · Profil et paramètres. Le réseau simulé se coupe ici.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    final net = Get.find<NetworkService>();
    var i = 0;
    Widget row(_Setting o) => FadeSlideIn(
        delay: Motion.stagger(i++, base: 150, step: 50),
        offset: const Offset(30, 0),
        child: o);

    return Column(children: [
      DarkHeader(
        child: Row(children: [
          FadeSlideIn(
            scale: .3,
            offset: Offset.zero,
            curve: Curves.elasticOut,
            duration: const Duration(milliseconds: 1100),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: Text(s.initials,
                  style: jakarta(20,
                      weight: FontWeight.w800, color: AppColors.forest)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.technicianFull,
                  style: jakarta(20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      tracking: -.02)),
              Text(s.scoop.isEmpty ? 'Technicien' : 'Technicien · ${s.scoop}',
                  style: jakarta(11, color: AppColors.white(.7))),
              const SizedBox(height: 2),
              Text(s.account.value.email,
                  style: mono(10, color: AppColors.white(.55))),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(16, 12, 16, ShellView.bottomInset(context)),
          children: [
            _Group(children: [
              row(_Setting(
                icon: Symbols.pin_rounded,
                title: 'Changer mon code PIN',
                sub: '4 chiffres',
                onTap: () => Get.toNamed(Routes.pinCreate, arguments: 'change'),
              )),
              row(_Setting(
                icon: Symbols.translate_rounded,
                title: 'Langue',
                sub: 'Français · wolof bientôt',
                onTap: () => showToast('Le wolof arrive bientôt.',
                    icon: Symbols.translate_rounded),
              )),
              row(_Setting(
                icon: Symbols.wifi_rounded,
                title: 'Réseau (simulation)',
                subWidget: Obx(() => Text(
                      net.online.value
                          ? 'Connecté · touchez pour couper'
                          : 'Coupé · touchez pour rétablir',
                      style: jakarta(10, color: AppColors.muted),
                    )),
                trailing: Obx(() => _Toggle(value: net.online.value)),
                onTap: net.toggle,
              )),
              row(_Setting(
                icon: Symbols.cloud_sync_rounded,
                title: 'Session API (technicien)',
                sub: Get.find<ApiClient>().accessToken == null
                    ? 'Non connecté · requis pour créer sur le serveur'
                    : 'Connecté · créations envoyées au serveur',
                onTap: () => _connectApi(context),
              )),
              row(_Setting(
                icon: Symbols.smartphone_rounded,
                title: 'État du téléphone',
                sub:
                    '${212 + s.activeProducers.length - MockData.producers.length} fiches · 248 parcelles · carte 38 Mo',
                last: true,
              )),
            ]),
            const SizedBox(height: 8),
            _Group(children: [
              row(_Setting(
                icon: Symbols.visibility_rounded,
                title: 'Aperçu espace producteur',
                sub: 'Ce que voit un producteur',
                bg: AppColors.blueSoft,
                ink: AppColors.blueInk,
                onTap: () => Get.toNamed(Routes.producerSpace),
              )),
              row(_Setting(
                icon: Symbols.lock_rounded,
                title: 'Verrouiller',
                sub: 'Retour au code PIN',
                onTap: () => Get.offAllNamed(Routes.unlock),
              )),
              row(_Setting(
                icon: Symbols.logout_rounded,
                title: 'Se déconnecter',
                sub: 'Efface la session et les données de cet appareil',
                onTap: () async {
                  final ok = await confirmSheet(
                    title: 'Se déconnecter ?',
                    message:
                        'La session et les données enregistrées sur ce téléphone seront effacées. Vous devrez vous reconnecter.',
                    confirmLabel: 'Se déconnecter',
                    icon: Symbols.logout_rounded,
                    destructive: true,
                  );
                  if (!ok) return;
                  Get.find<SessionService>().revoke();
                  Get.offAllNamed(Routes.phone);
                },
              )),
              row(_Setting(
                icon: Symbols.mobile_off_rounded,
                title: 'Simuler une révocation',
                sub: 'Prototype',
                bg: AppColors.redSoft,
                ink: AppColors.redInk,
                last: true,
                onTap: () {
                  Get.find<SessionService>().revoke();
                  Get.offAllNamed(Routes.revoked);
                },
              )),
            ]),
            const SizedBox(height: 16),
            Center(
                child: Text('v0.1.0 · prototype · données fictives',
                    style: mono(9, color: AppColors.gray))),
          ],
        ),
      ),
    ]);
  }
}

/// Connexion API technicien (email + OTP) pour envoyer les créations producteur au serveur.
Future<void> _connectApi(BuildContext context) async {
  final email = TextEditingController(text: 'fatou.sarr@cradesc.example');
  final password = TextEditingController(text: 'Demonstration2026');
  final otp = TextEditingController(text: '000000');
  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: Text('Session API', style: jakarta(16, weight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress),
          TextField(
              controller: password,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true),
          TextField(
              controller: otp,
              decoration: const InputDecoration(labelText: 'OTP'),
              keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Connecter')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final auth = Get.find<AuthService>();
    final challenge =
        await auth.signIn(email: email.text.trim(), password: password.text);
    await auth.verifyOtp(challengeId: challenge.id, code: otp.text.trim());
    final me = await auth.me();
    final scoop = me.scoopName ?? me.role;
    showToast(
      scoop.isEmpty ? 'API connectée' : 'API · $scoop',
      icon: Symbols.check_circle_rounded,
    );
  } catch (_) {
    showToast('Connexion API impossible', icon: Symbols.cloud_off_rounded);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(children: children),
      );
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.icon,
    required this.title,
    this.sub,
    this.subWidget,
    this.trailing,
    this.onTap,
    this.bg = AppColors.sage,
    this.ink = AppColors.ink,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? sub;
  final Widget? subWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color bg;
  final Color ink;
  final bool last;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: .97,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            IconTile(icon,
                size: 34,
                radius: 11,
                bg: bg,
                fg: ink == AppColors.ink ? AppColors.forest : ink,
                iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            jakarta(12, weight: FontWeight.w800, color: ink)),
                    subWidget ??
                        Text(sub ?? '',
                            style: jakarta(10, color: AppColors.muted)),
                  ]),
            ),
            trailing ??
                const Sym(Symbols.chevron_right_rounded,
                    size: 18, color: AppColors.faint),
          ]),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.medium,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: value ? AppColors.forest : AppColors.sand,
            borderRadius: BorderRadius.circular(13)),
        child: AnimatedAlign(
          duration: Motion.medium,
          curve: Motion.spring,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                color: value ? AppColors.lime : Colors.white,
                shape: BoxShape.circle),
          ),
        ),
      );
}
