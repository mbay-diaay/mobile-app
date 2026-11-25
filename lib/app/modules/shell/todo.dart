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

/// 22 · À compléter — seed MockData ou todos dérivés de la session API.
class TodoController extends GetxController {
  final filter = 0.obs;
  final session = Get.find<SessionService>();

  List<TodoItem> get _all => session.buildTodos();

  List<TodoItem> get items => switch (filter.value) {
        1 => _all.where((t) => !t.isPlot).toList(),
        2 => _all.where((t) => t.isPlot).toList(),
        _ => _all,
      };

  void open(TodoItem t) {
    if (t.isPlot) {
      final bits = t.subtitle.split(' · ');
      final code = bits.first;
      final ownerName = bits.length > 1 ? bits[1] : bits.first;
      final owner = session.activeProducers
              .firstWhereOrNull((p) => p.name == ownerName || p.code == code) ??
          session.activeProducers.firstWhereOrNull((p) => true);
      if (owner == null) return;
      final plot = session.plotsOf(owner).firstWhereOrNull((p) => p.code == code) ??
          Plot(
            code.startsWith('PA') ? code : session.nextPlotCode(),
            '—',
            '—',
            'À reprendre',
            AppColors.amberSoft,
            AppColors.amberInk,
          );
      Get.toNamed(Routes.plotValidate, arguments: {
        'owner': owner,
        'plot': plot,
      });
    } else {
      final name = t.subtitle.split(' · ').first;
      final p = session.activeProducers.firstWhereOrNull((p) => p.name == name);
      if (p != null) Get.toNamed(Routes.producer, arguments: p);
    }
  }
}

class TodoTab extends GetView<TodoController> {
  const TodoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionService>();
    return Obx(() {
      final allItems = s.buildTodos();
      final all = allItems.length;
      final plots = allItems.where((t) => t.isPlot).length;
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
            const SizedBox(height: 14),
            Obx(() {
              final f = controller.filter.value;
              return Row(
                  children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Pressable(
                    onTap: () => controller.filter.value = i,
                    child: Chip2(
                      label: labels[i],
                      bg: f == i ? AppColors.lime : AppColors.white(.12),
                      fg: f == i ? AppColors.forest : Colors.white,
                    ),
                  ),
                ],
              ]);
            }),
          ]),
        ),
        Expanded(
          child: Obx(() {
            final rows = controller.items;
            if (rows.isEmpty) {
              return Center(
                child: Text(
                  s.usingDemoCatalog.value
                      ? 'Rien à compléter'
                      : 'Aucune tâche — annuaire à jour',
                  style: jakarta(14, color: AppColors.muted),
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, ShellView.bottomInset(context) + 16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = rows[i];
                return FadeSlideIn(
                  delay: Motion.stagger(i, base: 40, step: 40),
                  child: Pressable(
                    onTap: () => controller.open(t),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.bg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Sym(t.icon, size: 22, color: t.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style:
                                      jakarta(14, weight: FontWeight.w800)),
                              Text(t.subtitle,
                                  style:
                                      jakarta(12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        const Sym(Symbols.chevron_right_rounded,
                            size: 22, color: AppColors.muted),
                      ]),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ]);
    });
  }
}
