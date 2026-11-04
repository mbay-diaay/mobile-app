import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

/// 20 · Synchronisation hors ligne (à corriger) — 21 · envoi en cours.
class SyncController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final net = Get.find<NetworkService>();
  final session = Get.find<SessionService>();
  late final AnimationController send = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600));
  final sent = false.obs;
  late final Worker _w;

  @override
  void onInit() {
    super.onInit();
    send.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        session.markSent();
        sent.value = true;
      }
    });
    _w = ever(net.online, (_) => _maybeSend());
  }

  @override
  void onReady() {
    super.onReady();
    _maybeSend();
  }

  void _maybeSend() {
    if (net.online.value && session.pending.isNotEmpty && !send.isAnimating) {
      Future.delayed(
          const Duration(milliseconds: 500), () => send.forward(from: 0));
    } else if (!net.online.value) {
      send.stop();
    }
  }

  /// Nombre d'éléments déjà envoyés selon l'avancement.
  int sentCount(int total) => (send.value * total).floor();

  @override
  void onClose() {
    _w.dispose();
    send.dispose();
    super.onClose();
  }
}

class SyncView extends GetView<SyncController> {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = controller.session;
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Column(children: [
          DarkHeader(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Obx(() {
              final online = controller.net.online.value;
              final sent = controller.sent.value;
              final (
                IconData icon,
                Color bg,
                Color fg,
                String title,
                String sub
              ) = sent || (online && s.pending.isEmpty)
                  ? (
                      Symbols.cloud_done_rounded,
                      AppColors.lime,
                      AppColors.forest,
                      'Tout est envoyé',
                      'Le serveur a bien reçu vos données.'
                    )
                  : online
                      ? (
                          Symbols.cloud_sync_rounded,
                          AppColors.lime,
                          AppColors.forest,
                          'Envoi en cours…',
                          'Ne coupez pas le réseau.'
                        )
                      : (
                          Symbols.cloud_off_rounded,
                          AppColors.white(.1),
                          Colors.white,
                          '${s.toFix.length} élément${s.toFix.length > 1 ? 's' : ''} à corriger',
                          'Pas de réseau. Tout reste gardé sur le téléphone.'
                        );
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      SquareIconButton.onDark(onTap: Get.back),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('Synchronisation',
                              style: jakarta(13,
                                  weight: FontWeight.w700,
                                  color: Colors.white))),
                      Chip2(
                        label: online ? 'Réseau' : 'Hors ligne',
                        icon: online
                            ? Symbols.wifi_rounded
                            : Symbols.wifi_off_rounded,
                        bg: AppColors.white(.1),
                        fg: Colors.white,
                        onTap: controller.net.toggle,
                      ),
                    ]),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      transitionBuilder: (w, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                            scale: Tween(begin: .9, end: 1.0).animate(a),
                            child: w),
                      ),
                      child: Row(key: ValueKey(title), children: [
                        online && !sent && s.pending.isNotEmpty
                            ? Spin(
                                child: IconTile(icon,
                                    size: 60,
                                    radius: 20,
                                    bg: bg,
                                    fg: fg,
                                    iconSize: 32))
                            : FadeSlideIn(
                                scale: .3,
                                offset: Offset.zero,
                                curve: Curves.elasticOut,
                                duration: const Duration(milliseconds: 1000),
                                child: IconTile(icon,
                                    size: 60,
                                    radius: 20,
                                    bg: bg,
                                    fg: fg,
                                    iconSize: 32),
                              ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: jakarta(22,
                                        weight: FontWeight.w800,
                                        color: Colors.white,
                                        tracking: -.03,
                                        height: 1.1)),
                                const SizedBox(height: 4),
                                Text(sub,
                                    style: jakarta(12,
                                        color: AppColors.white(.7))),
                              ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: online
                          ? AnimatedBuilder(
                              key: const ValueKey('bar'),
                              animation: controller.send,
                              builder: (_, __) => ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: sent ? 1 : controller.send.value,
                                  minHeight: 8,
                                  backgroundColor: AppColors.white(.12),
                                  color: AppColors.lime,
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('off'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                  color: AppColors.white(.08),
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Sym(Symbols.schedule_send_rounded,
                                    size: 16, color: AppColors.lime),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      "L'envoi partira tout seul quand le réseau reviendra.",
                                      style: jakarta(11, color: Colors.white)),
                                ),
                              ]),
                            ),
                    ),
                  ]);
            }),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, 16 + MediaQuery.paddingOf(context).bottom),
              children: [
                Obx(() => s.toFix.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            _SectionTitle(
                                count: s.toFix.length,
                                label: 'À corriger',
                                bg: AppColors.coral,
                                fg: AppColors.maroon),
                            const SizedBox(height: 8),
                            for (final (i, issue) in s.toFix.indexed)
                              FadeSlideIn(
                                key: ValueKey(issue.title),
                                delay: Motion.stagger(i, base: 200, step: 80),
                                offset: const Offset(-40, 0),
                                child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _IssueCard(issue: issue)),
                              ),
                            const SizedBox(height: 4),
                          ])),
                Obx(() {
                  final items = s.pending.toList();
                  final online = controller.net.online.value;
                  if (items.isEmpty) {
                    return FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          const IconTile(Symbols.done_all_rounded,
                              size: 40, radius: 13),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text("Rien en attente d'envoi.",
                                  style: jakarta(13, weight: FontWeight.w700))),
                        ]),
                      ),
                    );
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(
                            count: items.length,
                            label: "En attente d'envoi",
                            bg: AppColors.amberSoft,
                            fg: AppColors.amberInk),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 350),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20)),
                            child: AnimatedBuilder(
                              animation: controller.send,
                              builder: (_, __) {
                                final done = online
                                    ? controller.sentCount(items.length)
                                    : 0;
                                return Column(children: [
                                  for (final (i, it) in items.indexed)
                                    _PendingRow(
                                        item: it,
                                        last: i == items.length - 1,
                                        state:
                                            !online ? 0 : (i < done ? 2 : 1)),
                                ]);
                              },
                            ),
                          ),
                        ),
                      ]);
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.count,
      required this.label,
      required this.bg,
      required this.fg});
  final int count;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 22),
          height: 22,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
          alignment: Alignment.center,
          child: Text('$count',
              style: jakarta(11, weight: FontWeight.w800, color: fg)),
        ),
        const SizedBox(width: 6),
        Text(label, style: jakarta(12, weight: FontWeight.w800)),
      ]);
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});
  final SyncIssue issue;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(issue.icon,
              size: 36,
              radius: 12,
              bg: AppColors.redSoft,
              fg: AppColors.redInk,
              iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(issue.title, style: jakarta(13, weight: FontWeight.w800)),
              Text('Fiche · ${issue.owner}',
                  style: jakarta(11, color: AppColors.muted)),
              const SizedBox(height: 3),
              Text(issue.detail, style: jakarta(11)),
            ]),
          ),
          const SizedBox(width: 6),
          Pressable(
            onTap: () => Get.toNamed(Routes.fix, arguments: issue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Corriger',
                  style: jakarta(11,
                      weight: FontWeight.w800, color: AppColors.lime)),
            ),
          ),
        ]),
      );
}

/// state : 0 = en attente (hors ligne), 1 = en cours, 2 = envoyé.
class _PendingRow extends StatelessWidget {
  const _PendingRow(
      {required this.item, required this.last, required this.state});
  final PendingItem item;
  final bool last;
  final int state;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Sym(item.icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
              child: Text(item.label,
                  style: jakarta(12, weight: FontWeight.w600))),
          AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (w, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                child: w),
            child: switch (state) {
              2 => const Icon(Symbols.check_circle_rounded,
                  key: ValueKey(2), size: 18, color: AppColors.green, fill: 1),
              1 => const Spin(
                  key: ValueKey(1),
                  child: Icon(Symbols.progress_activity_rounded,
                      size: 18, color: AppColors.forest)),
              _ => const Icon(Symbols.schedule_rounded,
                  key: ValueKey(0), size: 18, color: AppColors.gray),
            },
          ),
        ]),
      );
}
