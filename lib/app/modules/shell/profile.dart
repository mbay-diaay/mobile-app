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
import '../../services/locale_service.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/layout.dart';
import 'shell.dart';
import "package:flutter/foundation.dart";

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
                title: 'profile.pin'.tr,
                sub: '4 chiffres',
                onTap: () => Get.toNamed(Routes.pinCreate, arguments: 'change'),
              )),
              row(_Setting(
                icon: Symbols.translate_rounded,
                title: 'profile.language'.tr,
                subWidget: Obx(() {
                  final loc = Get.find<LocaleService>();
                  return Text(
                    loc.label,
                    style: jakarta(10, color: AppColors.muted),
                  );
                }),
                onTap: () async {
                  await Get.find<LocaleService>().toggle();
                  showToast(
                      '${'profile.language'.tr} · ${Get.find<LocaleService>().label}',
                      icon: Symbols.translate_rounded);
                },
              )),
              row(_Setting(
                icon: Symbols.wifi_rounded,
                title: 'profile.network'.tr,
                subWidget: Obx(() => Text(
                      net.online.value
                          ? 'profile.networkOn'.tr
                          : 'profile.networkOff'.tr,
                      style: jakarta(10, color: AppColors.muted),
                    )),
                trailing: Obx(() => _Toggle(value: net.online.value)),
                onTap: () {
                  net.toggle();
                  showToast(
                    net.online.value
                        ? 'offline.toastOn'.tr
                        : 'offline.toastOff'.tr,
                    icon: net.online.value
                        ? Symbols.wifi_rounded
                        : Symbols.wifi_off_rounded,
                  );
                },
              )),
              row(_Setting(
                icon: Symbols.smartphone_rounded,
                title: 'État du téléphone',
                sub: () {
                  final n = s.activeProducers.length;
                  final plots = s.plots.values.fold<int>(0, (a, l) => a + l.length);
                  return '$n fiche${n > 1 ? 's' : ''} · $plots parcelle${plots > 1 ? 's' : ''}';
                }(),
                last: true,
              )),
            ]),
            const SizedBox(height: 8),
            _Group(children: [
              if (!kReleaseMode) ...[
                row(_Setting(
                  icon: Symbols.cloud_sync_rounded,
                  title: 'Session API (technicien)',
                  sub: Get.find<ApiClient>().accessToken == null
                      ? 'Non connecté · debug seulement'
                      : 'Connecté · créations envoyées au serveur',
                  onTap: () => _connectApi(context),
                )),
                row(_Setting(
                  icon: Symbols.visibility_rounded,
                  title: 'Aperçu espace producteur',
                  sub: 'Maquette 23 · parcelles, calendrier, alertes',
                  bg: AppColors.blueSoft,
                  ink: AppColors.blueInk,
                  onTap: () => Get.toNamed(Routes.producerSpace),
                )),
                row(_Setting(
                  icon: Symbols.agriculture_rounded,
                  title: 'profile.producerPreview'.tr,
                  sub: 'profile.producerPreviewSub'.tr,
                  onTap: () => Get.toNamed(
                    Routes.producerHome,
                    arguments: AuthUser(
                      id: 'seed-producer-push',
                      email: ProducerSeed.user.email,
                      name: ProducerSeed.user.name,
                      role: AuthUser.producerRole,
                      scoopName: ProducerSeed.user.scoopName,
                    ),
                  ),
                )),
                row(_Setting(
                  icon: Symbols.mobile_off_rounded,
                  title: 'Simuler une révocation',
                  sub: 'Debug',
                  bg: AppColors.redSoft,
                  ink: AppColors.redInk,
                  onTap: () async {
                    await Get.find<SessionService>().revoke();
                    Get.offAllNamed(Routes.revoked);
                  },
                )),
              ],
              row(_Setting(
                icon: Symbols.swap_horiz_rounded,
                title: 'profile.changeRole'.tr,
                sub: 'profile.changeRoleSub'.tr,
                onTap: () async => _confirmWipeThen(
                  title: 'Changer de rôle ?',
                  message:
                      'La session et les données non envoyées (hors ligne) seront effacées.',
                  confirmLabel: 'Changer de rôle',
                ),
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
                last: true,
                onTap: () async => _confirmWipeThen(
                  title: 'Se déconnecter ?',
                  message:
                      'La session et les données enregistrées sur ce téléphone seront effacées. Vous devrez vous reconnecter.',
                  confirmLabel: 'Se déconnecter',
                ),
              )),
            ]),
            const SizedBox(height: 16),
            Center(
                child: Text('v0.1.0 · Mbay Diaay',
                    style: mono(9, color: AppColors.gray))),
          ],
        ),
      ),
    ]);
  }
}

Future<void> _confirmWipeThen({
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final session = Get.find<SessionService>();
  final pending = await session.hasPendingOutbox();
  final ok = await confirmSheet(
    title: title,
    message: pending
        ? '$message\n\nAttention : des saisies hors ligne ne sont pas encore synchronisées.'
        : message,
    confirmLabel: confirmLabel,
    icon: Symbols.logout_rounded,
    destructive: true,
  );
  if (!ok) return;
  await session.revoke();
  Get.offAllNamed(Routes.roleGate);
}

/// Connexion API technicien (email + OTP) — debug uniquement.
Future<void> _connectApi(BuildContext context) async {
  if (kReleaseMode) return;
  final email = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: Text('Session API (debug)',
          style: jakarta(16, weight: FontWeight.w700)),
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
  } catch (e) {
    debugPrint("[ERROR][Profile._connectApi] ${e}");
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
