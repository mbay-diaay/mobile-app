import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/producer_seed.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/layout.dart';

/// Données d’aperçu (seed) pour que le producteur comprenne l’écran.
class _DemoPlot {
  const _DemoPlot(this.code, this.crop, this.ha, this.campaign, this.village);
  final String code;
  final String crop;
  final double ha;
  final String campaign;
  final String village;
}

class _DemoEvent {
  const _DemoEvent(this.title, this.when, this.status);
  final String title;
  final String when;
  final String status; // done | soon | now
}

const _demoPlots = [
  _DemoPlot('P-0142', 'Oignon', 0.45, '2025-2026', 'Mboro'),
  _DemoPlot('P-0143', 'Tomate', 0.28, '2025-2026', 'Mboro'),
  _DemoPlot('P-0188', 'Chou', 0.12, '2025-2026', 'Kayar'),
];

const _demoEvents = [
  _DemoEvent('Semis oignon · P-0142', '12 nov. 2025', 'done'),
  _DemoEvent('Traitement mildiou · P-0143', 'Cette semaine', 'now'),
  _DemoEvent('Récolte chou · P-0188', 'Début déc.', 'soon'),
];

class ProducerHomeController extends GetxController {
  late AuthUser user;
  final tab = 0.obs;

  /// Ouvert en push depuis le Profil technicien — bouton retour.
  bool get isPreview => user.id == 'preview' || user.id == 'seed-producer-push';

  /// Seed / aperçu : on montre des données d’exemple pour expliquer l’UI.
  bool get showDemoData =>
      user.id == ProducerSeed.id ||
      user.id == 'seed-producer-push' ||
      user.id == 'preview' ||
      user.id.isEmpty;

  @override
  void onInit() {
    super.onInit();
    user = (Get.arguments as AuthUser?) ??
        const AuthUser(
            id: '', email: '', name: 'Producteur', role: 'producteur');
  }

  Future<void> logout() async {
    if (isPreview) {
      Get.back();
      return;
    }
    await Get.find<AuthService>().logout();
    await Get.find<SessionService>().clearAppRole();
    Get.offAllNamed(Routes.roleGate);
  }
}

class ProducerHomeView extends GetView<ProducerHomeController> {
  const ProducerHomeView({super.key});

  static double bottomInset(BuildContext context) =>
      92 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final bottom = bottomInset(context);
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(children: [
          Positioned.fill(
            child: Obx(() => AnimatedSwitcher(
                  duration: Motion.medium,
                  child: KeyedSubtree(
                    key: ValueKey(c.tab.value),
                    child: switch (c.tab.value) {
                      0 => _HomeTab(
                            user: c.user,
                            bottom: bottom,
                            showBack: c.isPreview,
                            demo: c.showDemoData,
                            onOpenPlots: () => c.tab.value = 1,
                            onOpenCal: () => c.tab.value = 2,
                          ),
                      1 => _PlotsTab(bottom: bottom, demo: c.showDemoData),
                      2 => _CalendarTab(bottom: bottom, demo: c.showDemoData),
                      _ => _ProfileTab(
                          user: c.user,
                          bottom: bottom,
                          onLogout: c.logout,
                        ),
                    },
                  ),
                )),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: Obx(() => FloatingNavBar(
                  index: c.tab.value,
                  onTap: (i) => c.tab.value = i,
                  icons: FloatingNavBar.producerIcons,
                  badge: 0,
                  badgeIndex: -1,
                )),
          ),
        ]),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.bottom,
    required this.demo,
    required this.onOpenPlots,
    required this.onOpenCal,
    this.showBack = false,
  });
  final AuthUser user;
  final double bottom;
  final bool demo;
  final bool showBack;
  final VoidCallback onOpenPlots;
  final VoidCallback onOpenCal;

  @override
  Widget build(BuildContext context) {
    final ha = demo
        ? _demoPlots.fold<double>(0, (n, p) => n + p.ha)
        : 0.0;
    final crop = demo ? _demoPlots.first.crop : '—';
    final nPlots = demo ? _demoPlots.length : 0;

    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBack) ...[
              SquareIconButton.onDark(onTap: Get.back),
              const SizedBox(height: 12),
            ],
            Text('prod.home.hello'.tr,
                style: jakarta(13, color: AppColors.white(.7))),
            const SizedBox(height: 4),
            Text(user.name.isEmpty ? 'role.producer'.tr : user.name,
                style: display(26, color: Colors.white)),
            if (user.scoopName != null && user.scoopName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(user.scoopName!,
                  style: jakarta(13, color: AppColors.lime)),
            ],
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
          children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('prod.home.space'.tr,
                        style: jakarta(12, color: AppColors.white(.7))),
                    const SizedBox(height: 6),
                    Text('prod.home.spaceSub'.tr,
                        style: jakarta(16,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: Motion.stagger(1),
              child: Text('prod.home.stats'.tr,
                  style: jakarta(16, weight: FontWeight.w800, tracking: -.01)),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: Motion.stagger(2),
              child: Row(children: [
                Expanded(
                    child: _StatCard(
                        label: 'prod.home.statPlots'.tr, value: '$nPlots')),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        label: 'prod.home.statHa'.tr,
                        value: ha == 0 ? '—' : ha.toStringAsFixed(2))),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        label: 'prod.home.statCrop'.tr, value: crop, small: true)),
              ]),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: Motion.stagger(3),
              child: Text('prod.home.next'.tr,
                  style: jakarta(16, weight: FontWeight.w800, tracking: -.01)),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: Motion.stagger(4),
              child: _ActionRow(
                icon: Symbols.pentagon_rounded,
                title: 'prod.home.nextPlot'.tr,
                sub: 'prod.home.nextPlotSub'.tr,
                onTap: onOpenPlots,
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: Motion.stagger(5),
              child: _ActionRow(
                icon: Symbols.calendar_month_rounded,
                title: 'prod.home.nextCal'.tr,
                sub: 'prod.home.nextCalSub'.tr,
                onTap: onOpenCal,
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: Motion.stagger(6),
              child: _ActionRow(
                icon: Symbols.edit_note_rounded,
                title: 'prod.home.correction'.tr,
                sub: 'prod.home.correctionSub'.tr,
                onTap: () =>
                    Get.toNamed(Routes.correctionRequest, arguments: user),
              ),
            ),
            if (demo) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: Motion.stagger(7),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Sym(Symbols.info_rounded,
                        size: 20, color: AppColors.forest),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('prod.home.hint'.tr,
                          style: jakarta(12,
                              color: AppColors.forest, height: 1.4)),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, this.small = false});
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: jakarta(11, color: AppColors.muted, height: 1.2)),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: jakarta(small ? 15 : 22,
                  weight: FontWeight.w800,
                  color: AppColors.forest,
                  tracking: -.02)),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(children: [
            IconTile(icon, size: 44, radius: 14, fill: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: jakarta(14, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub, style: jakarta(12, color: AppColors.muted)),
                ],
              ),
            ),
            const Sym(Symbols.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      );
}

class _PlotsTab extends StatelessWidget {
  const _PlotsTab({required this.bottom, required this.demo});
  final double bottom;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prod.plots'.tr, style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text('prod.plotsLead'.tr,
                style: jakarta(13, color: AppColors.white(.7))),
          ],
        ),
      ),
      Expanded(
        child: !demo
            ? _EmptyBody(
                bottom: bottom,
                icon: Symbols.pentagon_rounded,
                body: 'prod.plotsEmpty'.tr,
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
                itemCount: _demoPlots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = _demoPlots[i];
                  return FadeSlideIn(
                    delay: Motion.stagger(i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.sage),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(p.code,
                                  style: mono(11,
                                      weight: FontWeight.w700,
                                      color: AppColors.forest)),
                            ),
                            const Spacer(),
                            Text(p.campaign,
                                style: jakarta(11, color: AppColors.muted)),
                          ]),
                          const SizedBox(height: 10),
                          Text(p.crop,
                              style: jakarta(18,
                                  weight: FontWeight.w800, tracking: -.02)),
                          const SizedBox(height: 4),
                          Text('${p.village} · ${p.ha.toStringAsFixed(2)} ha',
                              style: jakarta(13, color: AppColors.muted)),
                          const SizedBox(height: 12),
                          Row(children: [
                            _Pill(
                                label:
                                    '${'prod.plot.measured'.tr} ${p.ha.toStringAsFixed(2)} ha'),
                            const SizedBox(width: 6),
                            _Pill(
                                label:
                                    '${'prod.plot.declared'.tr} ${(p.ha * 1.05).toStringAsFixed(2)} ha'),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.bottom, required this.demo});
  final double bottom;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prod.calendar'.tr, style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text('prod.calendarLead'.tr,
                style: jakarta(13, color: AppColors.white(.7))),
          ],
        ),
      ),
      Expanded(
        child: !demo
            ? _EmptyBody(
                bottom: bottom,
                icon: Symbols.calendar_month_rounded,
                body: 'prod.calendarEmpty'.tr,
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
                itemCount: _demoEvents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final e = _demoEvents[i];
                  final (bg, fg, label) = switch (e.status) {
                    'done' => (
                        AppColors.sage,
                        AppColors.forest,
                        'prod.cal.done'.tr
                      ),
                    'now' => (
                        AppColors.lime,
                        AppColors.forest,
                        'prod.cal.now'.tr
                      ),
                    _ => (
                        AppColors.amberIconBg,
                        AppColors.amberInk,
                        'prod.cal.soon'.tr
                      ),
                  };
                  return FadeSlideIn(
                    delay: Motion.stagger(i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.sage),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Sym(Symbols.event_rounded, color: fg, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  style: jakarta(14, weight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(e.when,
                                  style:
                                      jakarta(12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(label,
                              style: jakarta(11,
                                  weight: FontWeight.w800, color: fg)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody(
      {required this.bottom, required this.icon, required this.body});
  final double bottom;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(28, 40, 28, bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTile(icon, size: 64, radius: 20, iconSize: 32, fill: true),
            const SizedBox(height: 18),
            Text(body,
                textAlign: TextAlign.center,
                style: jakarta(14, color: AppColors.muted, height: 1.45)),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.sage,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: jakarta(11, weight: FontWeight.w700, color: AppColors.forest)),
      );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.bottom,
    required this.onLogout,
  });
  final AuthUser user;
  final double bottom;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prod.profile'.tr, style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text('prod.role'.tr,
                style: jakarta(13, color: AppColors.white(.7))),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sage),
              ),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    (user.name.isEmpty ? 'P' : user.name[0]).toUpperCase(),
                    style: jakarta(18,
                        weight: FontWeight.w800, color: AppColors.forest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name.isEmpty ? 'role.producer'.tr : user.name,
                          style: jakarta(16, weight: FontWeight.w800)),
                      if (user.scoopName != null)
                        Text(user.scoopName!,
                            style: jakarta(12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _InfoLine(
              label: 'prod.profile.phone'.tr,
              value: user.id == ProducerSeed.id ||
                      user.id == 'seed-producer-push'
                  ? ProducerSeed.phoneDisplay
                  : '—',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              label: 'prod.profile.scoop'.tr,
              value: user.scoopName ?? '—',
            ),
            const SizedBox(height: 14),
            Text('prod.profile.help'.tr,
                style: jakarta(12, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 20),
            SwipeCta.dark(
              label: 'prod.logout'.tr,
              busyLabel: 'common.busy'.tr,
              onConfirm: onLogout,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(children: [
          Text(label, style: jakarta(13, color: AppColors.muted)),
          const Spacer(),
          Text(value, style: jakarta(14, weight: FontWeight.w800)),
        ]),
      );
}
