import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import 'shell.dart';

/// 22 · À compléter, avec filtres Tout / Fiches / Parcelles.
class TodoController extends GetxController {
  final filter = 0.obs;

  List<TodoItem> get items => switch (filter.value) {
        1 => MockData.todos.where((t) => !t.isPlot).toList(),
        2 => MockData.todos.where((t) => t.isPlot).toList(),
        _ => MockData.todos,
      };

  void open(TodoItem t) {
    if (t.isPlot) {
      Get.toNamed(Routes.survey);
    } else {
      final name = t.subtitle.split(' · ').first;
      final p = MockData.producers.firstWhereOrNull((p) => p.name == name) ??
          MockData.producers[5];
      Get.toNamed(Routes.producer, arguments: p);
    }
  }
}

class TodoTab extends GetView<TodoController> {
  const TodoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    final all = MockData.todos.length;
    final plots = MockData.todos.where((t) => t.isPlot).length;
    final labels = [
      'Tout · $all',
      'Fiches · ${all - plots}',
      'Parcelles · $plots'
    ];
    return Column(children: [
      DarkHeader(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('À compléter',
                    style: display(26, color: Colors.white))),
            Obx(() => s.toFix.isEmpty
                ? const SizedBox.shrink()
                : Chip2(
                    label: '${s.toFix.length} à corriger',
                    icon: Symbols.error_rounded,
                    onTap: () => Get.toNamed(Routes.sync))),
          ]),
          const SizedBox(height: 8),
          Text('Fiches et parcelles de votre SCOOP à reprendre.',
              style: jakarta(12, color: AppColors.white(.7))),
          const SizedBox(height: 12),
          Obx(() => Row(children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Chip2(
                    label: labels[i],
                    bg: controller.filter.value == i
                        ? AppColors.lime
                        : AppColors.white(.1),
                    fg: controller.filter.value == i
                        ? AppColors.forest
                        : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    onTap: () => controller.filter.value = i,
                  ),
                ],
              ])),
        ]),
      ),
      Expanded(
        child: Obx(() {
          final list = controller.items;
          return ListView.separated(
            key: ValueKey(controller.filter.value),
            physics: const BouncingScrollPhysics(),
            padding:
                EdgeInsets.fromLTRB(16, 12, 16, ShellView.bottomInset(context)),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = list[i];
              return FadeSlideIn(
                delay: Motion.stagger(i, step: 55, base: 100),
                offset: const Offset(0, 30),
                scale: .9,
                child: Pressable(
                  scale: .97,
                  onTap: () => controller.open(t),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24)),
                    child: Row(children: [
                      IconTile(t.icon,
                          size: 48,
                          radius: 16,
                          bg: t.bg,
                          fg: t.ink,
                          iconSize: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: jakarta(15,
                                      weight: FontWeight.w800,
                                      height: 1.25,
                                      tracking: -.01)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Sym(
                                    t.isPlot
                                        ? Symbols.pentagon_rounded
                                        : Symbols.person_rounded,
                                    size: 14,
                                    color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(t.subtitle,
                                        style: jakarta(12.5,
                                            color: AppColors.muted),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                            ]),
                      ),
                      const SizedBox(width: 6),
                      const Sym(Symbols.chevron_right_rounded,
                          size: 24, color: AppColors.faint),
                    ]),
                  ),
                ),
              );
            },
          );
        }),
      ),
    ]);
  }
}
