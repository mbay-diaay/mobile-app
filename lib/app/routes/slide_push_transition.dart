import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../core/app_theme.dart';

/// Activation : la page suivante arrive de la droite et pousse la page
/// courante vers la gauche, les deux bougeant ensemble (effet carrousel).
///
/// [animation] fait entrer la page ; [secondaryAnimation] (la page suivante
/// qui entre) la fait sortir. Avec [fadeIn], l'entrée se fait en fondu
/// (première page, après le démarrage) mais la sortie reste un glissé.
class SlidePushTransition extends CustomTransition {
  SlidePushTransition({this.fadeIn = false});
  final bool fadeIn;

  static const curve = Motion.emphasized;

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter =
        CurvedAnimation(parent: animation, curve: SlidePushTransition.curve);
    final exit = CurvedAnimation(
        parent: secondaryAnimation, curve: SlidePushTransition.curve);
    final entering = fadeIn
        ? FadeTransition(opacity: enter, child: child)
        : SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(enter),
            child: child,
          );
    return SlideTransition(
      position:
          Tween(begin: Offset.zero, end: const Offset(-1, 0)).animate(exit),
      child: entering,
    );
  }
}
