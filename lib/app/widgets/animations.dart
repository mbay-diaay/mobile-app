import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Apparition en glissé + fondu + léger rebond. Brique de base des cascades.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 28),
    this.scale = 1,
    this.curve = Motion.spring,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scale;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = CurvedAnimation(parent: _c, curve: widget.curve);
    final fade = CurvedAnimation(
        parent: _c, curve: const Interval(0, .6, curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: fade.value,
        child: Transform.translate(
          offset: widget.offset * (1 - move.value),
          child: Transform.scale(
            scale: widget.scale + (1 - widget.scale) * move.value,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Réduit légèrement l'élément pendant l'appui, puis rebondit.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, this.onTap, this.scale = .95});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.medium,
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Point qui « respire » avec un halo (réseau actif, hors ligne…).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s + s * 1.4 * _c.value,
            height: s + s * 1.4 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: .35 * (1 - _c.value)),
            ),
          ),
          Container(
              width: s,
              height: s,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Mise à l'échelle douce en boucle (icônes héroïques, alertes).
class Breathing extends StatefulWidget {
  const Breathing(
      {super.key,
      required this.child,
      this.amount = .06,
      this.period = const Duration(milliseconds: 1800)});
  final Widget child;
  final double amount;
  final Duration period;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1.0, end: 1 + widget.amount)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

/// Secoue son enfant à chaque incrément de [trigger] (PIN faux, total refusé).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = _c.value;
          final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// Nombre qui compte jusqu'à sa valeur.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 0,
    this.suffix = '',
    this.prefix = '',
    this.duration = const Duration(milliseconds: 1100),
    this.suffixStyle,
  });

  final double value;
  final TextStyle style;
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? suffixStyle;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Motion.smooth,
        builder: (_, v, __) => Text.rich(TextSpan(children: [
          TextSpan(
              text:
                  '$prefix${v.toStringAsFixed(decimals).replaceAll('.', ',')}',
              style: style),
          if (suffix.isNotEmpty)
            TextSpan(text: suffix, style: suffixStyle ?? style),
        ])),
      );
}

/// Flèche qui avance-recule en boucle, pour inviter à l'action.
class NudgeX extends StatefulWidget {
  const NudgeX({super.key, required this.child, this.distance = 3});
  final Widget child;
  final double distance;

  @override
  State<NudgeX> createState() => _NudgeXState();
}

class _NudgeXState extends State<NudgeX> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          // Deux petits élans, puis une pause.
          final t = _c.value;
          final dx =
              t < .5 ? math.sin(t * 4 * math.pi).abs() * widget.distance : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// Rotation continue (icône de synchronisation).
class Spin extends StatefulWidget {
  const Spin(
      {super.key,
      required this.child,
      this.period = const Duration(milliseconds: 1200)});
  final Widget child;
  final Duration period;

  @override
  State<Spin> createState() => _SpinState();
}

class _SpinState extends State<Spin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: widget.child);
}
