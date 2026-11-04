import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'animations.dart';

/// Icône Material Symbols arrondie, remplie ou non.
class Sym extends StatelessWidget {
  const Sym(this.icon,
      {super.key, this.size = 22, this.color, this.fill = false});
  final IconData icon;
  final double size;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, fill: fill ? 1 : 0);
}

/// Carré arrondi contenant une icône (motif omniprésent de la maquette).
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.size = 44,
    this.radius = 14,
    this.bg = AppColors.lime,
    this.fg = AppColors.forest,
    this.iconSize = 22,
    this.fill = false,
  });

  final IconData icon;
  final double size;
  final double radius;
  final Color bg;
  final Color fg;
  final double iconSize;
  final bool fill;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.medium,
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(radius)),
        alignment: Alignment.center,
        child: Sym(icon, size: iconSize, color: fg, fill: fill),
      );
}

/// Bouton d'action principal : libellé à gauche, carré d'icône à droite.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    this.icon = Symbols.arrow_forward_rounded,
    this.onTap,
    this.bg = AppColors.lime,
    this.fg = AppColors.forest,
    this.iconBg = AppColors.forest,
    this.iconFg = AppColors.lime,
    this.height = 60,
    this.nudge = true,
    this.fillIcon = false,
  });

  /// Variante vert forêt (« Valider », « Enregistrer »).
  const CtaButton.dark({
    super.key,
    required this.label,
    this.icon = Symbols.arrow_forward_rounded,
    this.onTap,
    this.height = 60,
    this.nudge = true,
    this.fillIcon = false,
  })  : bg = AppColors.forest,
        fg = Colors.white,
        iconBg = AppColors.lime,
        iconFg = AppColors.forest;

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final Color iconBg;
  final Color iconFg;
  final double height;
  final bool nudge;
  final bool fillIcon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Widget tile = IconTile(icon,
        size: height - 16, bg: iconBg, fg: iconFg, fill: fillIcon);
    if (nudge && enabled) tile = NudgeX(child: tile);
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : .45,
        child: AnimatedContainer(
          duration: Motion.medium,
          height: height,
          padding: const EdgeInsets.only(left: 22, right: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: jakarta(16, weight: FontWeight.w800, color: fg))),
            tile,
          ]),
        ),
      ),
    );
  }
}

/// CTA à glisser : on tire le carré d'icône vers la droite pour valider.
/// Pendant [onConfirm] le carré reste au bout et tourne ; il revient ensuite
/// au départ (tout de suite si l'écran est resté affiché, par exemple numéro
/// refusé, sinon une fois la page recouverte).
class SwipeCta extends StatefulWidget {
  const SwipeCta({
    super.key,
    required this.label,
    this.busyLabel,
    this.onConfirm,
    this.icon = Symbols.arrow_forward_rounded,
    this.bg = AppColors.lime,
    this.fg = AppColors.forest,
    this.iconBg = AppColors.forest,
    this.iconFg = AppColors.lime,
    this.height = 60,
  });

  /// Variante vert forêt.
  const SwipeCta.dark({
    super.key,
    required this.label,
    this.busyLabel,
    this.onConfirm,
    this.icon = Symbols.arrow_forward_rounded,
    this.height = 60,
  })  : bg = AppColors.forest,
        fg = Colors.white,
        iconBg = AppColors.lime,
        iconFg = AppColors.forest;

  final String label;
  final String? busyLabel;
  final FutureOr<void> Function()? onConfirm;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color iconBg;
  final Color iconFg;
  final double height;

  @override
  State<SwipeCta> createState() => _SwipeCtaState();
}

class _SwipeCtaState extends State<SwipeCta> with TickerProviderStateMixin {
  /// Position du carré, de 0 (départ) à 1 (bout de la piste).
  late final _pos = AnimationController(vsync: this, duration: Motion.medium);
  late final _shimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  bool _busy = false;
  double _travel = 1;

  bool get _enabled => widget.onConfirm != null && !_busy;

  @override
  void dispose() {
    _pos.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    if (_enabled) _pos.value += d.primaryDelta! / _travel;
  }

  void _release(DragEndDetails d) {
    if (!_enabled) return;
    final v = d.primaryVelocity ?? 0;
    if (_pos.value > .8 || (v > 900 && _pos.value > .35)) {
      _confirm();
    } else {
      _pos.animateBack(0, duration: Motion.medium, curve: Motion.spring);
    }
  }

  /// Un toucher ne valide pas : le carré esquisse le geste attendu.
  Future<void> _hint() async {
    if (!_enabled || _pos.isAnimating) return;
    HapticFeedback.selectionClick();
    await _pos.animateTo(.18, duration: Motion.fast, curve: Motion.smooth);
    if (mounted)
      await _pos.animateBack(0,
          duration: Motion.medium, curve: Curves.elasticOut);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    await _pos.animateTo(1, duration: Motion.fast, curve: Motion.smooth);
    await widget.onConfirm!();
    if (!mounted) return;
    // Page quittée : on attend qu'elle soit recouverte avant de remettre à zéro.
    if (ModalRoute.of(context)?.isCurrent == false)
      await Future.delayed(Motion.page + Motion.fast);
    if (!mounted) return;
    setState(() => _busy = false);
    _pos.animateBack(0, duration: Motion.medium, curve: Motion.spring);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final thumb = h - 16;
    final label =
        _busy && widget.busyLabel != null ? widget.busyLabel! : widget.label;
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: widget.onConfirm != null || _busy ? 1 : .45,
      child: GestureDetector(
        onTap: _hint,
        onHorizontalDragUpdate: _drag,
        onHorizontalDragEnd: _release,
        child: AnimatedContainer(
          duration: Motion.medium,
          height: h,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: widget.bg, borderRadius: BorderRadius.circular(20)),
          child: LayoutBuilder(builder: (_, c) {
            _travel = (c.maxWidth - thumb).clamp(1, double.infinity);
            return AnimatedBuilder(
              animation: Listenable.merge([_pos, _shimmer]),
              builder: (_, __) {
                final p = _pos.value.clamp(0.0, 1.0);
                final x = p * _travel;
                return Stack(children: [
                  // Traînée qui suit le carré.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: x + thumb,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.iconBg.withValues(alpha: .12 + .1 * p),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  // Libellé qui s'efface à mesure qu'on glisse, avec un reflet qui file vers la droite.
                  Positioned.fill(
                    left: thumb + 8,
                    right: 8,
                    child: Opacity(
                      opacity: _busy ? 1 : (1 - p * 1.6).clamp(0.0, 1.0),
                      child: Row(children: [
                        Expanded(
                          child: ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (r) {
                              final t = _shimmer.value * 2 - .5;
                              return LinearGradient(
                                colors: [
                                  widget.fg,
                                  widget.fg.withValues(alpha: .35),
                                  widget.fg
                                ],
                                stops: [t - .2, t, t + .2]
                                    .map((s) => s.clamp(0.0, 1.0))
                                    .toList(),
                              ).createShader(r);
                            },
                            child: Text(label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: jakarta(15,
                                    weight: FontWeight.w800, color: widget.fg)),
                          ),
                        ),
                        if (!_busy)
                          Sym(Symbols.keyboard_double_arrow_right_rounded,
                              size: 20, color: widget.fg.withValues(alpha: .5)),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: x,
                    top: 0,
                    child: Transform.scale(
                      scale: 1 + .06 * math.sin(p * math.pi),
                      child: _busy
                          ? Container(
                              width: thumb,
                              height: thumb,
                              decoration: BoxDecoration(
                                  color: widget.iconBg,
                                  borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.center,
                              child: Spin(
                                  child: Sym(Symbols.progress_activity_rounded,
                                      color: widget.iconFg)),
                            )
                          : NudgeX(
                              distance: _enabled && p == 0 ? 4 : 0,
                              child: IconTile(widget.icon,
                                  size: thumb,
                                  bg: widget.iconBg,
                                  fg: widget.iconFg),
                            ),
                    ),
                  ),
                ]);
              },
            );
          }),
        ),
      ),
    );
  }
}

/// Bouton plein, contenu centré (icône facultative).
class FlatButton extends StatelessWidget {
  const FlatButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.bg = Colors.white,
    this.fg = AppColors.ink,
    this.iconColor,
    this.height = 50,
    this.radius = 20,
    this.border,
    this.size = 14,
    this.weight = FontWeight.w700,
    this.dashed = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final Color? iconColor;
  final double height;
  final double radius;
  final Color? border;
  final double size;
  final FontWeight weight;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[
        Sym(icon!, size: size + 6, color: iconColor ?? fg),
        const SizedBox(width: 8)
      ],
      Flexible(
          child: Text(label,
              style: jakarta(size, weight: weight, color: fg),
              overflow: TextOverflow.ellipsis)),
    ]);
    return Pressable(
      onTap: onTap,
      child: dashed
          ? CustomPaint(
              painter:
                  DashedBorderPainter(color: AppColors.faint, radius: radius),
              child: SizedBox(height: height, child: content),
            )
          : AnimatedContainer(
              duration: Motion.medium,
              height: height,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                border: border == null
                    ? null
                    : Border.all(color: border!, width: 1.5),
              ),
              child: content,
            ),
    );
  }
}

/// Bouton retour/fermer carré (36×36, radius 12).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    this.icon = Symbols.arrow_back_rounded,
    this.onTap,
    this.bg = Colors.white,
    this.fg = AppColors.ink,
    this.size = 36,
  });

  /// Sur fond sombre (blanc à 10 %).
  const SquareIconButton.onDark(
      {super.key,
      this.icon = Symbols.arrow_back_rounded,
      this.onTap,
      this.size = 36})
      : bg = const Color(0x1AFFFFFF),
        fg = Colors.white;

  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: .85,
        child: IconTile(icon,
            size: size, radius: size / 3, bg: bg, fg: fg, iconSize: 20),
      );
}

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter(
      {required this.color,
      this.radius = 16,
      this.width = 2,
      this.dash = 6,
      this.gap = 4});
  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset(width / 2, width / 2) &
          Size(size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}
