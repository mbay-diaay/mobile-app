import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../routes/slide_push_transition.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/ring_progress.dart';
import '../lock/unlock.dart';

/// 04 · Activation · téléchargement réel de l’annuaire (plus de compteurs fictifs).
class DownloadController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController progress;
  final loading = true.obs;
  final error = RxnString();
  final producerCount = 0.obs;
  final plotCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    progress = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void onReady() {
    super.onReady();
    _run();
  }

  Future<void> _run() async {
    loading.value = true;
    error.value = null;
    progress.forward(from: 0);
    final session = Get.find<SessionService>();
    // Jamais de MockData ici : annuaire API / cache uniquement.
    session.usingDemoCatalog.value = false;
    try {
      final err = await session.refreshProducers();
      if (err != null && session.producers.isEmpty) {
        error.value = err.userMessage;
      }
      producerCount.value = session.activeProducers.length;
      // Estimation parcelles : une passe légère sur les fiches déjà syncées (max 8).
      var plots = 0;
      final sample = session.activeProducers
          .where((p) => p.remoteId != null)
          .take(8)
          .toList();
      for (final p in sample) {
        try {
          await session.loadPlots(p);
          plots += session.plotsOf(p).length;
        } on ApiException {
          // Ignore : l’annuaire prime ; les parcelles se chargent à l’ouverture de fiche.
        }
      }
      plotCount.value = plots;
    } catch (e) {
      error.value = 'Téléchargement incomplet. Vous pourrez réessayer plus tard.';
    } finally {
      loading.value = false;
      if (progress.value < 1) {
        await progress.animateTo(1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
      }
    }
  }

  Future<void> finish() async {
    await Get.find<SessionService>().completeActivation();
    Get.offAll(
      () => const UnlockView(),
      routeName: Routes.unlock,
      binding: BindingsBuilder.put(() => UnlockController()),
      opaque: true,
      transition: Transition.rightToLeft,
      curve: SlidePushTransition.curve,
      duration: Motion.page,
    );
  }

  @override
  void onClose() {
    progress.dispose();
    super.onClose();
  }
}

class DownloadView extends GetView<DownloadController> {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: AnimatedBuilder(
              animation: controller.progress,
              builder: (_, __) {
                final p = controller.progress.value;
                final done = p >= 1 && !controller.loading.value;
                return Obx(() {
                  final nProd = controller.producerCount.value;
                  final nPlot = controller.plotCount.value;
                  final err = controller.error.value;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FadeSlideIn(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StepLabel(4, onDark: false),
                                StepIndicator(step: 4, onDark: false),
                              ]),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          scale: .9,
                          child: _HeroCard(
                              p: p, done: done, error: err != null),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: _Item(
                            icon: Symbols.groups_rounded,
                            title: 'Producteurs de la SCOOP',
                            sub: done
                                ? (nProd == 0
                                    ? 'Aucune fiche pour l’instant'
                                    : '$nProd fiche${nProd > 1 ? 's' : ''} synchronisée${nProd > 1 ? 's' : ''}')
                                : 'Téléchargement de l’annuaire…',
                            value: done ? 1 : (p * 0.7).clamp(0.0, 0.95),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 270),
                          child: _Item(
                            icon: Symbols.pentagon_rounded,
                            title: 'Parcelles',
                            sub: done
                                ? (nPlot == 0
                                    ? 'Parcelles disponibles à l’ouverture des fiches'
                                    : '$nPlot parcelle${nPlot > 1 ? 's' : ''} chargée${nPlot > 1 ? 's' : ''}')
                                : 'Préparation…',
                            value: done ? 1 : (p * 0.4).clamp(0.0, 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 340),
                          child: _Item(
                            icon: Symbols.lock_rounded,
                            title: 'Session sécurisée',
                            sub: 'PIN local · jetons API dans le trousseau',
                            value: done ? 1 : (p * 0.9).clamp(0.0, 0.95),
                          ),
                        ),
                        if (err != null) ...[
                          const SizedBox(height: 12),
                          Text(err,
                              textAlign: TextAlign.center,
                              style: jakarta(12,
                                  color: AppColors.coral,
                                  weight: FontWeight.w600)),
                        ],
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: Motion.medium,
                          child: done
                              ? SwipeCta(
                                  key: const ValueKey('go'),
                                  label: 'Glissez pour continuer',
                                  onConfirm: controller.finish)
                              : Row(
                                  key: const ValueKey('net'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const PulseDot(color: AppColors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                        'Réseau actif · synchronisation…',
                                        style: jakarta(12,
                                            weight: FontWeight.w600,
                                            color: AppColors.muted)),
                                  ],
                                ),
                        ),
                      ]);
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.p, required this.done, this.error = false});
  final double p;
  final bool done;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: AppColors.forest, borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          RingProgress(
            value: p,
            size: 112,
            thickness: 12,
            color: error ? AppColors.coral : AppColors.lime,
            track: AppColors.white(.12),
            inner: AppColors.forest,
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: done
                  ? Icon(
                      error
                          ? Symbols.warning_rounded
                          : Symbols.check_rounded,
                      key: ValueKey(error ? 'warn' : 'ok'),
                      size: 48,
                      color: error ? AppColors.coral : AppColors.lime,
                      weight: 700)
                  : Column(
                      key: const ValueKey('p'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(
                                text: '${(p * 100).round()}',
                                style: display(30,
                                    color: Colors.white, height: 1)),
                            TextSpan(
                                text: '%',
                                style: display(16, color: Colors.white)),
                          ])),
                        ]),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  done
                      ? (error ? 'Téléchargement partiel' : 'Téléphone prêt')
                      : 'Préparation du téléphone',
                  style: jakarta(20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      tracking: -.02,
                      height: 1.1)),
              const SizedBox(height: 6),
              Text(
                done
                    ? (error
                        ? 'Annuaire incomplet — réessayez plus tard depuis Accueil.'
                        : 'Données de votre SCOOP synchronisées.')
                    : 'Récupération de l’annuaire sur le serveur…',
                style: jakarta(12, color: AppColors.white(.7), height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.value});
  final IconData icon;
  final String title;
  final String sub;
  final double value;

  @override
  Widget build(BuildContext context) {
    final done = value >= 1;
    final active = value > 0 && !done;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: active ? AppColors.forest : AppColors.sage, width: 1.2),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: done ? AppColors.lime : AppColors.sage,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Sym(done ? Symbols.check_rounded : icon,
              size: 22, color: AppColors.forest),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: jakarta(14, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub, style: jakarta(12, color: AppColors.muted)),
              if (active) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: AppColors.sage,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
