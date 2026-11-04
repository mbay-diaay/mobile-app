import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../services/session_service.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/layout.dart';
import 'home.dart';
import 'map_tab.dart';
import 'producers.dart';
import 'profile.dart';
import 'todo.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ShellController());
    Get.lazyPut(() => ProducersController());
    Get.lazyPut(() => TodoController());
  }
}

class ShellController extends GetxController {
  final tab = 0.obs;
  int _previous = 0;

  /// +1 si on va vers la droite : sert à orienter le glissé entre onglets.
  int get direction => tab.value >= _previous ? 1 : -1;

  void go(int i) {
    if (i == tab.value) return;
    _previous = tab.value;
    tab.value = i;
  }
}

/// Coquille à 5 onglets (accueil, producteurs, carte, à faire, profil).
class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  /// Espace à réserver sous le contenu pour la barre flottante.
  static double bottomInset(BuildContext context) =>
      92 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        body: Stack(children: [
          Obx(() {
            final i = controller.tab.value;
            final dir = controller.direction;
            return AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.smooth,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) {
                final incoming = child.key == ValueKey(i);
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                            begin: Offset(incoming ? .08 * dir : -.08 * dir, 0),
                            end: Offset.zero)
                        .animate(a),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(key: ValueKey(i), child: _tab(i)),
            );
          }),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14 + MediaQuery.paddingOf(context).bottom,
            child: Obx(() => FloatingNavBar(
                  index: controller.tab.value,
                  onTap: controller.go,
                  badge: session.todoCount.value,
                )),
          ),
        ]),
      ),
    );
  }

  Widget _tab(int i) => switch (i) {
        0 => const HomeTab(),
        1 => const ProducersTab(),
        2 => const MapTab(),
        3 => const TodoTab(),
        _ => const ProfileTab(),
      };
}
