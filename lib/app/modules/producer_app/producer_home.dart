import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/producer_catalog.dart';
import '../../data/producer_seed.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/layout.dart';

/// Shell producteur — 5 onglets (Accueil, Parcelles, Calendrier, Alertes, Profil).
class ProducerHomeController extends GetxController {
  late AuthUser user;
  final tab = 0.obs;

  bool get isPreview => user.id == 'preview' || user.id == 'seed-producer-push';

  /// Catalogue fictif : seed / aperçu uniquement — jamais un vrai compte.
  bool get showCatalog => isSeed;

  bool get isSeed =>
      user.id == ProducerSeed.id ||
      user.id == 'seed-producer-push' ||
      user.id == 'preview';

  /// Alertes non lues (remis à 0 à l’ouverture de l’onglet).
  final alertsUnread = ProducerCatalog.alerts.length.obs;

  int get alertBadge => showCatalog ? alertsUnread.value : 0;

  @override
  void onInit() {
    super.onInit();
    final session = Get.find<SessionService>();
    user = (Get.arguments as AuthUser?) ??
        session.producerUser.value ??
        const AuthUser(
            id: '', email: '', name: 'Producteur', role: 'producteur');
    if (user.id.isNotEmpty && !isPreview) {
      unawaited(session.saveProducerUser(user));
    }
  }

  void go(int i) {
    tab.value = i;
    if (i == 3) alertsUnread.value = 0;
  }

  Future<void> logout() async {
    if (isPreview) {
      Get.back();
      return;
    }
    final session = Get.find<SessionService>();
    final pending = await session.hasPendingOutbox();
    final ok = await confirmSheet(
      title: 'prod.logoutConfirm'.tr,
      message: pending
          ? '${'prod.logoutConfirmSub'.tr}\n\nAttention : des saisies hors ligne ne sont pas encore synchronisées.'
          : 'prod.logoutConfirmSub'.tr,
      confirmLabel: 'prod.logoutConfirmCta'.tr,
      icon: Symbols.logout_rounded,
      destructive: true,
    );
    if (!ok) return;
    // revoke() appelle déjà logout — un seul passage.
    await session.revoke();
    Get.offAllNamed(Routes.roleGate);
  }

  Future<void> changeRole() async {
    if (isPreview) {
      Get.back();
      return;
    }
    final session = Get.find<SessionService>();
    final pending = await session.hasPendingOutbox();
    final ok = await confirmSheet(
      title: 'profile.changeRole'.tr,
      message: pending
          ? 'La session et les données non envoyées seront effacées.'
          : 'profile.changeRoleSub'.tr,
      confirmLabel: 'profile.changeRole'.tr,
      icon: Symbols.swap_horiz_rounded,
      destructive: true,
    );
    if (!ok) return;
    await session.revoke();
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
            child: Obx(() {
              final i = c.tab.value;
              return AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.smooth,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: .97, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(i),
                  child: switch (i) {
                    0 => _HomeTab(bottom: bottom),
                    1 => _PlotsTab(bottom: bottom),
                    2 => _CalendarTab(bottom: bottom),
                    3 => _AlertsTab(bottom: bottom),
                    _ => _ProfileTab(bottom: bottom),
                  },
                ),
              );
            }),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: Obx(() => FloatingNavBar(
                  index: c.tab.value,
                  onTap: c.go,
                  icons: FloatingNavBar.producerIcons,
                  badge: c.alertBadge,
                  badgeIndex: 3,
                )),
          ),
        ]),
      ),
    );
  }
}

String _frenchDate(DateTime d) {
  const days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche'
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre'
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'P';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ───────────────────────────── Accueil

class _HomeTab extends GetView<ProducerHomeController> {
  const _HomeTab({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final net = Get.find<NetworkService>();
    final demo = c.showCatalog;
    const plots = ProducerCatalog.plots;
    final ha = demo ? ProducerCatalog.totalHa : 0.0;
    var i = 0;
    Widget item(Widget w) =>
        FadeSlideIn(delay: Motion.stagger(i++, base: 80, step: 55), child: w);

    return Column(children: [
      DarkHeader(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (c.isPreview) ...[
              SquareIconButton.onDark(onTap: Get.back),
              const SizedBox(width: 10),
            ],
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(_initials(c.user.name),
                  style: jakarta(16,
                      weight: FontWeight.w800, color: AppColors.forest)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('prod.home.hello'.tr,
                      style: jakarta(11, color: AppColors.white(.6))),
                  Text(
                    c.user.name.isEmpty ? 'role.producer'.tr : c.user.name,
                    style: jakarta(18,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        tracking: -.02),
                  ),
                  Text(_frenchDate(DateTime.now()),
                      style: jakarta(11, color: AppColors.white(.55))),
                ],
              ),
            ),
            Obx(() => Chip2(
                  label: net.online.value
                      ? 'prod.home.online'.tr
                      : 'home.offline'.tr,
                  bg: AppColors.white(.1),
                  fg: Colors.white,
                  dot: PulseDot(
                    color: net.online.value ? AppColors.lime : AppColors.orange,
                    size: 7,
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
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
          ]),
          if (c.user.scoopName != null && c.user.scoopName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Sym(Symbols.groups_rounded,
                    size: 16, color: AppColors.lime),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.user.scoopName!,
                      style: jakarta(12,
                          weight: FontWeight.w600,
                          color: AppColors.white(.85))),
                ),
              ]),
            ),
          ],
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
          children: [
            item(Row(children: [
              Expanded(
                child: _BigTile(
                  icon: Symbols.pentagon_rounded,
                  title: 'prod.home.tilePlots'.tr,
                  sub: demo ? '${plots.length}' : '0',
                  variant: _TileVariant.lime,
                  onTap: () => c.go(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigTile(
                  icon: Symbols.edit_note_rounded,
                  title: 'prod.home.tileFix'.tr,
                  sub: 'prod.home.tileFixSub'.tr,
                  variant: _TileVariant.forest,
                  onTap: () => Get.toNamed(Routes.correctionRequest,
                      arguments: c.user),
                ),
              ),
            ])),
            const SizedBox(height: 14),
            item(Text('prod.home.stats'.tr,
                style: jakarta(16, weight: FontWeight.w800, tracking: -.01))),
            const SizedBox(height: 10),
            item(Row(children: [
              _Kpi(
                label: 'prod.home.statPlots'.tr,
                value: demo ? '${plots.length}' : '0',
                icon: Symbols.pentagon_rounded,
              ),
              const SizedBox(width: 8),
              _Kpi(
                label: 'prod.home.statHa'.tr,
                value: demo
                    ? ha.toStringAsFixed(2).replaceAll('.', ',')
                    : '—',
                icon: Symbols.square_foot_rounded,
              ),
              const SizedBox(width: 8),
              _Kpi(
                label: 'prod.home.statCrop'.tr,
                value: demo ? ProducerCatalog.mainCrop : '—',
                icon: Symbols.eco_rounded,
                small: true,
              ),
            ])),
            if (demo) ...[
              const SizedBox(height: 18),
              item(Row(children: [
                Text('prod.home.watch'.tr,
                    style: jakarta(16, weight: FontWeight.w800)),
                const Spacer(),
                Pressable(
                  onTap: () => c.go(3),
                  child: Text(
                    'prod.home.watchAll'.trParams(
                        {'n': '${ProducerCatalog.alerts.length}'}),
                    style: jakarta(12,
                        weight: FontWeight.w700, color: AppColors.forest),
                  ),
                ),
              ])),
              const SizedBox(height: 10),
              for (final (j, a) in ProducerCatalog.alerts.take(2).indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: j == 0 ? 8 : 0),
                  child: item(_AlertCard(alert: a, onTap: () => c.go(3))),
                ),
              const SizedBox(height: 18),
              item(Row(children: [
                Text('prod.home.myPlots'.tr,
                    style: jakarta(16, weight: FontWeight.w800)),
                const Spacer(),
                Pressable(
                  onTap: () => c.go(1),
                  child: Text('prod.home.seeAll'.tr,
                      style: jakarta(12,
                          weight: FontWeight.w700, color: AppColors.forest)),
                ),
              ])),
              const SizedBox(height: 10),
              for (final (j, p) in plots.take(2).indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: j == 0 ? 8 : 0),
                  child: item(_PlotCard(
                    plot: p,
                    onTap: () => _openPlotSheet(context, p),
                  )),
                ),
            ] else ...[
              const SizedBox(height: 18),
              item(_EmptyCard(
                icon: Symbols.agriculture_rounded,
                body: 'prod.home.empty'.tr,
              )),
            ],
            const SizedBox(height: 18),
            item(Text('prod.home.next'.tr,
                style: jakarta(16, weight: FontWeight.w800))),
            const SizedBox(height: 10),
            item(_ActionRow(
              icon: Symbols.calendar_month_rounded,
              title: 'prod.home.nextCal'.tr,
              sub: 'prod.home.nextCalSub'.tr,
              onTap: () => c.go(2),
            )),
            const SizedBox(height: 8),
            item(_ActionRow(
              icon: Symbols.notifications_rounded,
              title: 'prod.home.nextAlerts'.tr,
              sub: 'prod.home.nextAlertsSub'.tr,
              onTap: () => c.go(3),
            )),
            const SizedBox(height: 20),
            item(SwipeCta.dark(
              label: 'prod.home.ctaFix'.tr,
              onConfirm: () async => Get.toNamed(Routes.correctionRequest,
                  arguments: c.user),
            )),
          ],
        ),
      ),
    ]);
  }
}

enum _TileVariant { lime, forest }

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.variant,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final _TileVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lime = variant == _TileVariant.lime;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lime ? AppColors.lime : AppColors.forest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Sym(icon,
                size: 28,
                color: lime ? AppColors.forest : AppColors.lime,
                fill: true),
            const Spacer(),
            Text(title,
                style: jakarta(14,
                    weight: FontWeight.w800,
                    color: lime ? AppColors.forest : Colors.white,
                    height: 1.2)),
            const SizedBox(height: 2),
            Text(sub,
                style: jakarta(12,
                    weight: FontWeight.w600,
                    color: lime
                        ? AppColors.forest.withValues(alpha: .7)
                        : AppColors.white(.7))),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.small = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool small;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sym(icon, size: 18, color: AppColors.forest),
              const SizedBox(height: 8),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(small ? 14 : 22,
                      weight: FontWeight.w800,
                      color: AppColors.forest,
                      tracking: -.02)),
              const SizedBox(height: 2),
              Text(label, style: jakarta(11, color: AppColors.muted)),
            ],
          ),
        ),
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

// ───────────────────────────── Parcelles

class _PlotsTab extends GetView<ProducerHomeController> {
  const _PlotsTab({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final demo = controller.showCatalog;
    const plots = ProducerCatalog.plots;
    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prod.plots'.tr, style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              demo
                  ? 'prod.plotsLeadCount'.trParams({
                      'n': '${plots.length}',
                      'ha': ProducerCatalog.totalHa
                          .toStringAsFixed(2)
                          .replaceAll('.', ','),
                    })
                  : 'prod.plotsLead'.tr,
              style: jakarta(13, color: AppColors.white(.7)),
            ),
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
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
                itemCount: plots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = plots[i];
                  return FadeSlideIn(
                    delay: Motion.stagger(i),
                    child: _PlotCard(
                      plot: p,
                      dense: false,
                      onTap: () => _openPlotSheet(context, p),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _PlotCard extends StatelessWidget {
  const _PlotCard({
    required this.plot,
    required this.onTap,
    this.dense = true,
  });
  final ProducerPlotInfo plot;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(dense ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconTile(Symbols.pentagon_rounded,
                    size: 44, radius: 14, bg: AppColors.sage, fill: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${plot.code} · ${plot.haLabel}',
                          style: jakarta(14, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${plot.crop} · ${plot.village}',
                          style: jakarta(12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Chip2(
                  label: plot.status,
                  bg: plot.statusBg,
                  fg: plot.statusFg,
                  size: 10,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ]),
              if (!dense) ...[
                const SizedBox(height: 12),
                Row(children: [
                  _Pill(label: '${'prod.plot.measured'.tr} ${plot.haLabel}'),
                  const SizedBox(width: 6),
                  _Pill(
                      label:
                          '${'prod.plot.declared'.tr} ${plot.declaredLabel}'),
                ]),
                const SizedBox(height: 8),
                Text(plot.campaign,
                    style: jakarta(11, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      );
}

void _openPlotSheet(BuildContext context, ProducerPlotInfo plot) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text(plot.code,
                  style: mono(14,
                      weight: FontWeight.w700, color: AppColors.forest)),
              const Spacer(),
              Chip2(
                label: plot.status,
                bg: plot.statusBg,
                fg: plot.statusFg,
                size: 11,
              ),
            ]),
            const SizedBox(height: 8),
            Text(plot.crop, style: display(24)),
            const SizedBox(height: 4),
            Text('${plot.village} · ${plot.campaign}',
                style: jakarta(13, color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _SheetStat(
                    label: 'prod.plot.measured'.tr, value: plot.haLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetStat(
                    label: 'prod.plot.declared'.tr, value: plot.declaredLabel),
              ),
            ]),
            const SizedBox(height: 16),
            SwipeCta(
              label: 'prod.plot.openCal'.tr,
              onConfirm: () async {
                Get.back();
                Get.toNamed(Routes.cropCalendar, arguments: {
                  'crop': plot.crop.split(',').first.trim(),
                  'plot': plot.code,
                });
              },
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: jakarta(11, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: jakarta(18, weight: FontWeight.w800)),
        ]),
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
            style:
                jakarta(11, weight: FontWeight.w700, color: AppColors.forest)),
      );
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.body});
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, size: 44, radius: 14, fill: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(body,
                style: jakarta(13, color: AppColors.muted, height: 1.4)),
          ),
        ]),
      );
}

// ───────────────────────────── Calendrier

class _CalendarTab extends GetView<ProducerHomeController> {
  const _CalendarTab({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final demo = controller.showCatalog;
    const events = ProducerCatalog.events;
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
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
                children: [
                  const FadeSlideIn(child: _CampaignStrip()),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: Motion.stagger(1),
                    child: Text('prod.calendar.ops'.tr,
                        style: jakarta(16, weight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, e) in events.indexed)
                    Padding(
                      padding:
                          EdgeInsets.only(bottom: i < events.length - 1 ? 10 : 0),
                      child: FadeSlideIn(
                        delay: Motion.stagger(i + 2),
                        child: _EventCard(event: e),
                      ),
                    ),
                ],
              ),
      ),
    ]);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final ProducerEventInfo event;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (event.status) {
      'done' => (AppColors.sage, AppColors.forest, 'prod.cal.done'.tr),
      'now' => (AppColors.lime, AppColors.forest, 'prod.cal.now'.tr),
      _ => (AppColors.amberIconBg, AppColors.amberInk, 'prod.cal.soon'.tr),
    };
    return Container(
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
              Text(event.title, style: jakarta(14, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(event.when, style: jakarta(12, color: AppColors.muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child:
              Text(label, style: jakarta(11, weight: FontWeight.w800, color: fg)),
        ),
      ]),
    );
  }
}

class _CampaignStrip extends StatelessWidget {
  const _CampaignStrip();

  static const _months = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D'
  ];
  static const _rows = [
    [(10, 11, AppColors.orange), (11, 13, AppColors.purple)],
    [(1, 4, AppColors.forest), (4, 6, AppColors.lime)],
  ];
  static const _legend = [
    ('Semis', AppColors.orange),
    ('Repiquage', AppColors.purple),
    ('Entretien', AppColors.forest),
    ('Récolte', AppColors.lime),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('prod.calendar.campaign'.tr,
              style:
                  jakarta(12, weight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 10),
          Row(children: [
            for (final m in _months)
              Expanded(
                  child: Text(m,
                      textAlign: TextAlign.center,
                      style: jakarta(9,
                          weight: FontWeight.w700, color: AppColors.muted))),
          ]),
          for (final (r, row) in _rows.indexed) ...[
            const SizedBox(height: 7),
            SizedBox(
              height: 16,
              child: Row(children: [
                for (final (k, bar) in row.indexed) ...[
                  if (bar.$1 > (k == 0 ? 1 : row[k - 1].$2))
                    Spacer(flex: bar.$1 - (k == 0 ? 1 : row[k - 1].$2)),
                  Expanded(
                    flex: bar.$2 - bar.$1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            Duration(milliseconds: 700 + 200 * (r * 2 + k)),
                        curve: Motion.smooth,
                        builder: (_, t, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: bar.$3,
                                  borderRadius: BorderRadius.circular(5))),
                        ),
                      ),
                    ),
                  ),
                ],
                if (row.last.$2 < 13) Spacer(flex: 13 - row.last.$2),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final (l, c) in _legend)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(l, style: jakarta(10, weight: FontWeight.w600)),
              ]),
          ]),
        ]),
      );
}

// ───────────────────────────── Alertes

class _AlertsTab extends GetView<ProducerHomeController> {
  const _AlertsTab({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final demo = controller.showCatalog;
    const alerts = ProducerCatalog.alerts;
    return Column(children: [
      DarkHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prod.alerts'.tr, style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              demo
                  ? 'prod.alertsLead'.trParams({'n': '${alerts.length}'})
                  : 'prod.alertsEmptyLead'.tr,
              style: jakarta(13, color: AppColors.white(.7)),
            ),
          ],
        ),
      ),
      Expanded(
        child: !demo
            ? _EmptyBody(
                bottom: bottom,
                icon: Symbols.notifications_rounded,
                body: 'prod.alertsEmpty'.tr,
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => FadeSlideIn(
                  delay: Motion.stagger(i),
                  child: _AlertCard(alert: alerts[i]),
                ),
              ),
      ),
    ]);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, this.onTap});
  final ProducerAlertInfo alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: alert.tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Sym(alert.icon, size: 22, color: alert.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.title, style: jakarta(13, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(alert.sub,
                  style: jakarta(12, color: AppColors.muted, height: 1.3)),
            ],
          ),
        ),
      ]),
    );
    return onTap == null ? child : Pressable(onTap: onTap, child: child);
  }
}

// ───────────────────────────── Profil

class _ProfileTab extends GetView<ProducerHomeController> {
  const _ProfileTab({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final net = Get.find<NetworkService>();
    var i = 0;
    Widget row(_Setting o) => FadeSlideIn(
        delay: Motion.stagger(i++, base: 120, step: 45),
        offset: const Offset(24, 0),
        child: o);

    return Column(children: [
      DarkHeader(
        child: Row(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(_initials(c.user.name),
                style: jakarta(20,
                    weight: FontWeight.w800, color: AppColors.forest)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.user.name.isEmpty ? 'role.producer'.tr : c.user.name,
                  style: jakarta(20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      tracking: -.02),
                ),
                Text('prod.role'.tr,
                    style: jakarta(12, color: AppColors.white(.7))),
                if (c.user.scoopName != null && c.user.scoopName!.isNotEmpty)
                  Text(c.user.scoopName!,
                      style: jakarta(11, color: AppColors.white(.55))),
              ],
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          children: [
            _Group(children: [
              row(_Setting(
                icon: Symbols.call_rounded,
                title: 'prod.profile.phone'.tr,
                sub: c.isSeed ? ProducerSeed.phoneDisplay : '—',
              )),
              row(_Setting(
                icon: Symbols.groups_rounded,
                title: 'prod.profile.scoop'.tr,
                sub: c.user.scoopName ?? '—',
                last: true,
              )),
            ]),
            const SizedBox(height: 8),
            _Group(children: [
              row(_Setting(
                icon: Symbols.translate_rounded,
                title: 'profile.language'.tr,
                subWidget: Obx(() => Text(
                      Get.find<LocaleService>().label,
                      style: jakarta(10, color: AppColors.muted),
                    )),
                onTap: () async {
                  await Get.find<LocaleService>().toggle();
                  showToast(
                    '${'profile.language'.tr} · ${Get.find<LocaleService>().label}',
                    icon: Symbols.translate_rounded,
                  );
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
                last: true,
              )),
            ]),
            const SizedBox(height: 8),
            _Group(children: [
              row(_Setting(
                icon: Symbols.edit_note_rounded,
                title: 'prod.home.correction'.tr,
                sub: 'prod.home.correctionSub'.tr,
                onTap: () => Get.toNamed(Routes.correctionRequest,
                    arguments: c.user),
              )),
              row(_Setting(
                icon: Symbols.swap_horiz_rounded,
                title: 'profile.changeRole'.tr,
                sub: 'profile.changeRoleSub'.tr,
                onTap: c.changeRole,
              )),
              row(_Setting(
                icon: Symbols.logout_rounded,
                title: 'prod.profile.logout'.tr,
                sub: 'prod.profile.logoutSub'.tr,
                bg: AppColors.redSoft,
                ink: AppColors.redInk,
                last: true,
                onTap: c.logout,
              )),
            ]),
            const SizedBox(height: 14),
            Text('prod.profile.help'.tr,
                textAlign: TextAlign.center,
                style: jakarta(12, color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.sage),
        ),
        clipBehavior: Clip.antiAlias,
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
    this.last = false,
    this.bg,
    this.ink,
  });

  final IconData icon;
  final String title;
  final String? sub;
  final Widget? subWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final Color? bg;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final inkC = ink ?? AppColors.forest;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.sage)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg ?? AppColors.sage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Sym(icon, size: 20, color: inkC),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: jakarta(14, weight: FontWeight.w800)),
                if (subWidget != null) ...[
                  const SizedBox(height: 2),
                  subWidget!,
                ] else if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: jakarta(11, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            const Sym(Symbols.chevron_right_rounded,
                size: 20, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.fast,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.forest : AppColors.sage,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}
