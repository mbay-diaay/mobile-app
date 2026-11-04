import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'animations.dart';

/// Clavier 3×4 aux touches semi-transparentes (écrans 03 et 05).
class PinKeypad extends StatelessWidget {
  const PinKeypad(
      {super.key,
      required this.onDigit,
      required this.onBackspace,
      this.enabled = true});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++)
          FadeSlideIn(
            delay: Motion.stagger(i, step: 35, base: 200),
            offset: const Offset(0, 30),
            scale: .7,
            child: _Key(
              label: keys[i],
              onTap: !enabled || keys[i].isEmpty
                  ? null
                  : keys[i] == '<'
                      ? onBackspace
                      : () => onDigit(keys[i]),
            ),
          ),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final isDigit = widget.label.isNotEmpty && widget.label != '<';
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: _down ? const Duration(milliseconds: 60) : Motion.medium,
        curve: Curves.easeOut,
        width: 76,
        height: 60,
        transform: Matrix4.diagonal3Values(_down ? .9 : 1, _down ? .9 : 1, 1),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: !isDigit
              ? Colors.transparent
              : _down
                  ? AppColors.lime
                  : AppColors.white(.08),
        ),
        alignment: Alignment.center,
        child: widget.label == '<'
            ? const Icon(Symbols.backspace_rounded,
                color: Colors.white, size: 26)
            : Text(
                widget.label,
                style: jakarta(26,
                    weight: FontWeight.w700,
                    color: _down ? AppColors.forest : Colors.white),
              ),
      ),
    );
  }
}

/// Quatre cases de PIN (écran 03) : la case courante est soulignée en citron.
class PinBoxes extends StatelessWidget {
  const PinBoxes({super.key, required this.length, this.count = 4});
  final int length;
  final int count;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.spring,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 14),
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: i < length ? AppColors.lime : AppColors.white(.08),
              border: Border.all(
                  color: i == length ? AppColors.lime : Colors.transparent,
                  width: 2),
            ),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: i < length ? 1 : 0,
              duration: Motion.medium,
              curve: Curves.elasticOut,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.forest),
              ),
            ),
          ),
      ]);
}

/// Quatre points de PIN (écran 05).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.error = false});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: Motion.fast,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 18),
            width: 14,
            height: 14,
            transform: Matrix4.diagonal3Values(
                i == length - 1 ? 1.25 : 1, i == length - 1 ? 1.25 : 1, 1),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error
                  ? AppColors.coral
                  : (i < length ? AppColors.lime : Colors.transparent),
              border: Border.all(
                color: error
                    ? AppColors.coral
                    : (i < length ? AppColors.lime : AppColors.white(.4)),
                width: 2,
              ),
            ),
          ),
      ]);
}
