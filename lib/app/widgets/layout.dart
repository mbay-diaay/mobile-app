import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'animations.dart';

/// Fixe la couleur des icônes de la barre d'état selon le fond.
class StatusBarStyle extends StatelessWidget {
  const StatusBarStyle({super.key, required this.dark, required this.child});
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor:
              dark ? AppColors.forestDeep : AppColors.cream,
        ),
        child: child,
      );
}

/// En-tête vert forêt arrondi en bas (accueil, listes, synchro).
class DarkHeader extends StatelessWidget {
  const DarkHeader(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        offset: const Offset(0, -40),
        duration: Motion.slow,
        curve: Motion.smooth,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: SafeArea(
              bottom: false, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// Carte crème qui monte depuis le bas (formulaires d'activation, relevés).
class RisingSheet extends StatelessWidget {
  const RisingSheet({
    super.key,
    required this.child,
    this.color = AppColors.cream,
    this.radius = 32,
    this.padding = const EdgeInsets.all(24),
    this.delay = const Duration(milliseconds: 120),
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsets padding;
  final Duration delay;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        delay: delay,
        offset: const Offset(0, 260),
        duration: const Duration(milliseconds: 820),
        curve: Motion.emphasized,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
              color: color,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(radius))),
          padding: padding,
          child: SafeArea(top: false, child: child),
        ),
      );
}

/// Défile si le clavier réduit la place, sinon remplit la hauteur (les `Spacer`
/// poussent alors le bouton principal en bas, comme dans la maquette).
class FillScroll extends StatelessWidget {
  const FillScroll(
      {super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          padding: padding,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: c.maxHeight - padding.vertical),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );
}

/// Indicateur d'étape « ÉTAPE 0X / 04 » + points.
class StepIndicator extends StatelessWidget {
  const StepIndicator(
      {super.key, required this.step, this.total = 4, this.onDark = true});
  final int step;
  final int total;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final active = onDark ? AppColors.lime : AppColors.forest;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= total; i++)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 6, end: i == step ? 22 : 6),
          duration: Motion.slow,
          curve: Motion.spring,
          builder: (_, w, __) => Container(
            margin: const EdgeInsets.only(left: 4),
            width: w,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i <= step
                  ? active
                  : (onDark ? AppColors.white(.3) : AppColors.faint),
            ),
          ),
        ),
    ]);
  }
}

class StepLabel extends StatelessWidget {
  const StepLabel(this.step, {super.key, this.onDark = true});
  final int step;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text(
        'ÉTAPE 0$step / 04',
        style: mono(11,
            weight: FontWeight.w700,
            color: onDark ? AppColors.lime : AppColors.forest),
      );
}

/// Pastille arrondie (« Hors ligne », « 2 à corriger »…).
class Chip2 extends StatelessWidget {
  const Chip2({
    super.key,
    required this.label,
    this.icon,
    this.dot,
    this.bg = AppColors.coral,
    this.fg = AppColors.maroon,
    this.size = 11,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final String label;
  final IconData? icon;
  final Widget? dot;
  final Color bg;
  final Color fg;
  final double size;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          padding: padding,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot != null) ...[dot!, const SizedBox(width: 5)],
            if (icon != null) ...[
              Icon(icon, size: size + 3, color: fg),
              const SizedBox(width: 4)
            ],
            Text(label,
                style: jakarta(size, weight: FontWeight.w800, color: fg)),
          ]),
        ),
      );
}

/// Sélecteur segmenté avec pastille blanche (ou verte) qui glisse.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.dark = false,
    this.fontSize = 11,
    this.vPad = 8,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool dark;
  final double fontSize;
  final double vPad;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.sand, borderRadius: BorderRadius.circular(16)),
      // Sans LayoutBuilder : le sélecteur doit rester mesurable (IntrinsicHeight de FillScroll).
      child: Stack(children: [
        if (index >= 0)
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.medium,
              curve: Motion.spring,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? AppColors.forest : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: dark
                        ? null
                        : const [
                            BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2))
                          ],
                  ),
                ),
              ),
            ),
          ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 4),
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.fast,
                    textAlign: TextAlign.center,
                    style: jakarta(
                      fontSize,
                      weight: FontWeight.w700,
                      color: i == index
                          ? (dark ? AppColors.lime : AppColors.ink)
                          : AppColors.muted,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Bandeau éphémère en haut d'écran, au style de la maquette.
void showToast(String message,
    {IconData? icon, Color bg = AppColors.ink, Color fg = Colors.white}) {
  Get.rawSnackbar(
    messageText: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.lime, size: 20),
        const SizedBox(width: 10)
      ],
      Expanded(
          child: Text(message,
              style: jakarta(13, weight: FontWeight.w700, color: fg))),
    ]),
    backgroundColor: bg,
    borderRadius: 18,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(milliseconds: 1900),
    animationDuration: Motion.medium,
    forwardAnimationCurve: Motion.spring,
  );
}
