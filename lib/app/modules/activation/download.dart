import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../routes/slide_push_transition.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/ring_progress.dart';
import '../lock/unlock.dart';

/// 04 · Activation · téléchargement des données, simulé sur ~7 s.
class DownloadController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController progress;

  @override
  void onInit() {
    super.onInit();
    progress = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 7000));
  }

  @override
  void onReady() {
    super.onReady();
    Get.find<SessionService>().refreshProducers();
    Future.delayed(const Duration(milliseconds: 500), progress.forward);
  }

  /// Avancement d'une étape occupant la plage [a, b] de la progression totale.
  double part(double a, double b) =>
      ((progress.value - a) / (b - a)).clamp(0, 1);

  /// Le déverrouillage arrive de la droite et pousse cette page vers la gauche.
  void finish() {
    Get.find<SessionService>().completeActivation();
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
                final done = p >= 1;
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
                        child: _HeroCard(p: p, done: done),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: _Item(
                          icon: Symbols.groups_rounded,
                          title: 'Producteurs de la SCOOP',
                          sub:
                              '${(212 * controller.part(0, .25)).round()} / 212 fiches',
                          value: controller.part(0, .25),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 270),
                        child: _Item(
                          icon: Symbols.pentagon_rounded,
                          title: 'Parcelles',
                          sub:
                              '${(248 * controller.part(.25, .6)).round()} / 248 contours',
                          value: controller.part(.25, .6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 340),
                        child: _Item(
                          icon: Symbols.map_rounded,
                          title: 'Carte des Niayes',
                          sub: '38 Mo · utilisable hors ligne',
                          value: controller.part(.6, 1),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                              scale: CurvedAnimation(
                                  parent: a, curve: Motion.spring),
                              child: c),
                        ),
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
                                      "Réseau actif · ne fermez pas l'application",
                                      style: jakarta(12,
                                          weight: FontWeight.w600,
                                          color: AppColors.muted)),
                                ],
                              ),
                      ),
                    ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.p, required this.done});
  final double p;
  final bool done;

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
            color: AppColors.lime,
            track: AppColors.white(.12),
            inner: AppColors.forest,
            child: AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: c),
              child: done
                  ? const Icon(Symbols.check_rounded,
                      key: ValueKey('ok'),
                      size: 48,
                      color: AppColors.lime,
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
                          const SizedBox(height: 3),
                          Text('${(38 * p).round()} / 38 Mo',
                              style: mono(9, color: AppColors.white(.6))),
                        ]),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(done ? 'Téléphone prêt' : 'Préparation du téléphone',
                  style: jakarta(20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      tracking: -.02,
                      height: 1.1)),
              const SizedBox(height: 6),
              Text(
                done
                    ? 'Tout marche maintenant sans réseau.'
                    : 'Gardez le réseau. Ensuite, tout marche sans réseau.',
                style: jakarta(12, color: AppColors.white(.7), height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}

/// Ligne d'élément : en attente → en cours (bordure + barre) → terminé (coche).
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
    return AnimatedOpacity(
      duration: Motion.medium,
      opacity: value == 0 ? .6 : 1,
      child: AnimatedContainer(
        duration: Motion.medium,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.forest : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Row(children: [
            IconTile(
              icon,
              bg: done
                  ? AppColors.lime
                  : (active ? AppColors.forest : AppColors.sage),
              fg: done || !active ? AppColors.forest : AppColors.lime,
              fill: done,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: jakarta(14, weight: FontWeight.w700)),
                    Text(sub, style: jakarta(12, color: AppColors.muted)),
                  ]),
            ),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: c),
              child: done
                  ? Container(
                      key: const ValueKey('d'),
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: AppColors.forest, shape: BoxShape.circle),
                      child: const Icon(Symbols.check_rounded,
                          size: 18, color: AppColors.lime),
                    )
                  : active
                      ? Text('${(value * 100).round()}%',
                          key: const ValueKey('a'),
                          style: mono(12,
                              weight: FontWeight.w700, color: AppColors.forest))
                      : const Icon(Symbols.schedule_rounded,
                          key: ValueKey('w'), size: 20, color: AppColors.muted),
            ),
          ]),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.smooth,
            child: active
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: AppColors.sage,
                        color: AppColors.forest,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}
