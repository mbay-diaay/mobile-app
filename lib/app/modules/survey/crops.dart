import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/crop_catalog.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../sync/success.dart' show SuccessGroup, SuccessRow;
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';

const _seasons = ['Campagne horticole 2026', 'Contre-saison 2026'];
const _seasonShort = ['Horticole 2026', 'Contre-saison 2026'];

String _ha(double v) => v > 0 && v < .01
    ? '< 0,01 ha'
    : '${v.toStringAsFixed(2).replaceAll('.', ',')} ha';

/// 18 · 19 — Cultures de la parcelle : par saison, le total doit faire 100 %.
///
/// On ajoute depuis le catalogue (ou une culture libre), on modifie la culture,
/// sa variété et sa part en touchant la ligne, on supprime depuis la fiche ou en
/// glissant la ligne. Tout est local : aucun réseau n'est nécessaire.
class CropsController extends GetxController {
  late final Map _args = (Get.arguments as Map?) ?? {};
  late final String code = (_args['code'] as String?) ?? 'PA-0034';
  late final Producer owner =
      (_args['owner'] as Producer?) ?? MockData.producers[8];
  late final double area = (_args['area'] as double?) ?? .17;

  final session = Get.find<SessionService>();
  final season = 0.obs;
  final shake = 0.obs;

  /// Une liste de travail par saison, enregistrée seulement avec « Enregistrer ».
  final plans = <RxList<Crop>>[<Crop>[].obs, <Crop>[].obs];
  RxList<Crop> get crops => plans[season.value];

  @override
  void onInit() {
    super.onInit();
    for (var s = 0; s < plans.length; s++) {
      plans[s].assignAll(session.cropsOf(code, s));
    }
  }

  int _sum(List<Crop> l) => l.fold(0, (s, c) => s + c.share);
  int get total => _sum(crops);
  bool _seasonOk(int s) => plans[s].isEmpty || _sum(plans[s]) == 100;
  bool get valid =>
      (plans[0].isNotEmpty || plans[1].isNotEmpty) &&
      _seasonOk(0) &&
      _seasonOk(1);

  void change(Crop c, int delta) {
    final before = valid;
    c.share = (c.share + delta).clamp(0, 100);
    crops.refresh();
    if (before && !valid) shake.value++;
  }

  // ───────── Ajouter

  Future<void> add() async {
    final picked = await Get.bottomSheet<Object>(
      _CropPicker(taken: {for (final c in crops) c.name.toLowerCase()}),
      isScrollControlled: true,
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 420),
    );
    final spec = _specFrom(picked);
    if (spec == null) return;
    // La nouvelle culture prend ce qui reste pour atteindre 100 %.
    crops.add(spec.toCrop((100 - total).clamp(0, 100)));
    HapticFeedback.selectionClick();
  }

  CropSpec? _specFrom(Object? picked) => switch (picked) {
        CropSpec s => s,
        String name when name.trim().isNotEmpty =>
          CropCatalog.byName(name) ?? CropCatalog.custom(name, crops.length),
        _ => null,
      };

  // ───────── Modifier · supprimer

  Future<void> edit(Crop c) async {
    final r = await Get.bottomSheet<_CropEdit>(
      _EditSheet(crop: c, others: total - c.share),
      isScrollControlled: true,
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 420),
    );
    if (r == null) return;
    if (r.remove) return remove(c);
    c.variety = r.variety;
    c.share = r.share;
    if (r.change) await _replace(c);
    crops.refresh();
  }

  /// Change la culture elle-même en gardant sa part.
  Future<void> _replace(Crop c) async {
    final picked = await Get.bottomSheet<Object>(
      _CropPicker(taken: {
        for (final x in crops)
          if (x != c) x.name.toLowerCase()
      }),
      isScrollControlled: true,
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 420),
    );
    final spec = _specFrom(picked);
    if (spec == null) return;
    final n = spec.toCrop(c.share);
    c
      ..short = n.short
      ..name = n.name
      ..tint = n.tint
      ..ink = n.ink
      ..bar = n.bar
      ..variety = '';
  }

  void remove(Crop c) {
    crops.remove(c);
    showToast('${c.name} retirée', icon: Symbols.delete_rounded);
  }

  /// Répartit 100 % à parts égales (le reste va aux premières cultures).
  void splitEvenly() {
    final n = crops.length;
    if (n == 0) return;
    for (final (i, c) in crops.indexed) {
      c.share = 100 ~/ n + (i < 100 % n ? 1 : 0);
    }
    crops.refresh();
    HapticFeedback.selectionClick();
  }

  // ───────── Enregistrer

  void save() {
    if (plans[0].isEmpty && plans[1].isEmpty) {
      shake.value++;
      showToast('Ajoutez au moins une culture.',
          icon: Symbols.potted_plant_rounded);
      return;
    }
    if (!_seasonOk(season.value)) {
      shake.value++;
      return;
    }
    final other = 1 - season.value;
    if (!_seasonOk(other)) {
      season.value = other;
      shake.value++;
      showToast('Le total de « ${_seasons[other]} » doit faire 100 %.',
          icon: Symbols.error_rounded);
      return;
    }
    session.declareCrops(
        code, {for (var s = 0; s < plans.length; s++) s: plans[s].toList()});
    final groups = [
      for (var s = 0; s < plans.length; s++)
        if (plans[s].any((c) => c.share > 0))
          SuccessGroup(_seasons[s], [
            for (final c in plans[s])
              if (c.share > 0)
                SuccessRow(
                  short: c.short,
                  title: c.name,
                  subtitle: c.variety,
                  tint: c.tint,
                  ink: c.ink,
                  trailing: '${c.share} %',
                  caption: '≈ ${_ha(area * c.share / 100)}',
                  progress: c.share / 100,
                ),
          ]),
    ];
    Get.offNamed(Routes.success, arguments: {
      'title': 'Cultures déclarées',
      'sub': 'Parcelle $code · ${owner.name} · ${_ha(area)}',
      'cta': "Retour à l'accueil",
      'groups': groups,
    });
  }
}

class CropsView extends GetView<CropsController> {
  const CropsView({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: Row(children: [
                      SquareIconButton(onTap: Get.back),
                      const SizedBox(width: 10),
                      Text('Cultures de la parcelle', style: display(20)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const IconTile(Symbols.pentagon_rounded,
                            size: 40, radius: 13),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(controller.owner.name,
                                    style: jakarta(14,
                                        weight: FontWeight.w800,
                                        color: Colors.white)),
                                Text(
                                    '${controller.code} · ${_ha(controller.area)}',
                                    style:
                                        mono(10, color: AppColors.white(.65))),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: Obx(() => SegmentedPill(
                          labels: [
                            for (var s = 0; s < _seasons.length; s++)
                              controller.plans[s].isEmpty
                                  ? _seasonShort[s]
                                  : '${_seasonShort[s]} · ${controller.plans[s].length}',
                          ],
                          index: controller.season.value,
                          onChanged: controller.season.call,
                        )),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Obx(() {
                      final list = controller.crops;
                      final s = controller.season.value;
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          if (list.isEmpty)
                            FadeSlideIn(
                              key: ValueKey('empty$s'),
                              delay: const Duration(milliseconds: 200),
                              child: const _EmptyState(),
                            )
                          else ...[
                            for (final (i, c) in list.indexed)
                              FadeSlideIn(
                                key: ValueKey('$s-${c.name}'),
                                delay: Motion.stagger(i, base: 200, step: 70),
                                offset: const Offset(40, 0),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Dismissible(
                                    key: ObjectKey(c),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) => controller.remove(c),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                          color: AppColors.redSoft,
                                          borderRadius:
                                              BorderRadius.circular(22)),
                                      child: const Sym(Symbols.delete_rounded,
                                          size: 26, color: AppColors.redInk),
                                    ),
                                    child: _CropRow(c: c, ctrl: controller),
                                  ),
                                ),
                              ),
                            Shake(
                                trigger: controller.shake.value,
                                child: _TotalBox(ctrl: controller)),
                            const SizedBox(height: 10),
                          ],
                          FlatButton(
                            label: 'Ajouter une culture',
                            icon: Symbols.add_rounded,
                            dashed: true,
                            height: 50,
                            radius: 16,
                            size: 13,
                            onTap: controller.add,
                          ),
                          if (list.length >= 2 && controller.total != 100) ...[
                            const SizedBox(height: 8),
                            FlatButton(
                              label: 'Répartir à parts égales',
                              icon: Symbols.percent_rounded,
                              bg: AppColors.sage,
                              fg: AppColors.forest,
                              height: 46,
                              radius: 16,
                              size: 13,
                              onTap: controller.splitEvenly,
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => Pressable(
                        onTap: controller.save,
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          height: 58,
                          decoration: BoxDecoration(
                            color: controller.valid
                                ? AppColors.forest
                                : AppColors.sand,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text('Enregistrer',
                              style: jakarta(16,
                                  weight: FontWeight.w800,
                                  color: controller.valid
                                      ? Colors.white
                                      : AppColors.gray)),
                        ),
                      )),
                ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const IconTile(Symbols.potted_plant_rounded,
              size: 56,
              radius: 18,
              bg: AppColors.sage,
              fg: AppColors.forest,
              iconSize: 28),
          const SizedBox(height: 12),
          Text('Aucune culture pour cette saison',
              style: jakarta(15, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Ajoutez les cultures de la parcelle, puis répartissez-les : le total doit faire 100 %.',
            textAlign: TextAlign.center,
            style: jakarta(12.5, color: AppColors.muted, height: 1.4),
          ),
        ]),
      );
}

class _CropRow extends StatelessWidget {
  const _CropRow({required this.c, required this.ctrl});
  final Crop c;
  final CropsController ctrl;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: .98,
        onTap: () => ctrl.edit(c),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: c.tint, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text(c.short,
                  style: jakarta(13, weight: FontWeight.w800, color: c.ink)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: jakarta(14, weight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    Text(c.variety.isEmpty ? 'Variété (facultatif)' : c.variety,
                        style: jakarta(11,
                            color: c.variety.isEmpty
                                ? AppColors.faint
                                : AppColors.muted),
                        overflow: TextOverflow.ellipsis),
                    if (c.share > 0)
                      Text('≈ ${_ha(ctrl.area * c.share / 100)}',
                          style: mono(10, color: AppColors.muted)),
                  ]),
            ),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _Step(
                    icon: Symbols.remove_rounded,
                    onTap: () => ctrl.change(c, -5)),
                SizedBox(
                  width: 46,
                  child: AnimatedSwitcher(
                    duration: Motion.fast,
                    transitionBuilder: (w, a) =>
                        ScaleTransition(scale: a, child: w),
                    child: Text('${c.share} %',
                        key: ValueKey(c.share),
                        textAlign: TextAlign.center,
                        style: jakarta(15, weight: FontWeight.w800)),
                  ),
                ),
                _Step(
                    icon: Symbols.add_rounded, onTap: () => ctrl.change(c, 5)),
              ]),
            ),
          ]),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: .8,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16),
        ),
      );
}

/// Barre empilée + verdict (vert si 100 %, rouge sinon).
class _TotalBox extends StatelessWidget {
  const _TotalBox({required this.ctrl});
  final CropsController ctrl;

  @override
  Widget build(BuildContext context) => Obx(() => _build());

  Widget _build() {
    final total = ctrl.total;
    final ok = total == 100;
    final (bg, ink, icon, msg) = ok
        ? (
            AppColors.lime,
            AppColors.forest,
            Symbols.check_circle_rounded,
            'Total 100 % : parcelle complète'
          )
        : total > 100
            ? (
                AppColors.redSoft,
                AppColors.redDark,
                Symbols.error_rounded,
                'Total $total % : retirez ${total - 100} %'
              )
            : (
                AppColors.amberSoft,
                AppColors.amberInk,
                Symbols.info_rounded,
                'Total $total % : ajoutez ${100 - total} %'
              );
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 10,
            color: const Color(0x14000000),
            child: Builder(builder: (_) {
              final crops = ctrl.crops.where((x) => x.share > 0).toList();
              return Row(children: [
                for (final (i, x) in crops.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: x.share,
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      decoration: BoxDecoration(
                        color: total > 100 && i == crops.length - 1
                            ? AppColors.red
                            : x.bar,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
                if (total < 100) Spacer(flex: 100 - total),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: Row(key: ValueKey(msg), children: [
            Icon(icon, size: 18, color: ink),
            const SizedBox(width: 6),
            Expanded(
                child: Text(msg,
                    style: jakarta(13, weight: FontWeight.w800, color: ink))),
          ]),
        ),
      ]),
    );
  }
}

// ───────────────────────────── Fiches (bottom sheets)

Widget _sheet(BuildContext context, {required Widget child}) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 18, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: child,
      ),
    );

/// Choix d'une culture : catalogue avec recherche, ou une culture libre.
/// Renvoie un [CropSpec] (catalogue) ou un [String] (nom libre).
class _CropPicker extends StatefulWidget {
  const _CropPicker({required this.taken});
  final Set<String> taken;

  @override
  State<_CropPicker> createState() => _CropPickerState();
}

class _CropPickerState extends State<_CropPicker> {
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim();
    final list = [
      for (final s in CropCatalog.all)
        if (s.name.toLowerCase().contains(query.toLowerCase())) s,
    ];
    final exact = CropCatalog.byName(query) != null ||
        widget.taken.contains(query.toLowerCase());
    final maxH = MediaQuery.sizeOf(context).height * .5;
    return _sheet(
      context,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choisir une culture',
                style: jakarta(18, weight: FontWeight.w800, tracking: -.02)),
            const SizedBox(height: 12),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Sym(Symbols.search_rounded,
                    size: 20, color: AppColors.gray),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _q,
                    textCapitalization: TextCapitalization.sentences,
                    style: jakarta(14, weight: FontWeight.w700),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Rechercher ou écrire une culture',
                      hintStyle: jakarta(14, color: AppColors.faint),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (final s in list)
                    _PickRow(
                        spec: s,
                        taken: widget.taken.contains(s.name.toLowerCase())),
                  if (query.isNotEmpty && !exact)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FlatButton(
                        label: 'Ajouter « $query » comme autre culture',
                        icon: Symbols.add_rounded,
                        bg: AppColors.forest,
                        fg: Colors.white,
                        iconColor: AppColors.lime,
                        height: 50,
                        radius: 16,
                        size: 13,
                        weight: FontWeight.w800,
                        onTap: () => Get.back(result: query),
                      ),
                    ),
                  if (list.isEmpty && query.isEmpty) const SizedBox.shrink(),
                ],
              ),
            ),
          ]),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.spec, required this.taken});
  final CropSpec spec;
  final bool taken;

  @override
  Widget build(BuildContext context) {
    final c = spec.toCrop();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        scale: .98,
        onTap: taken ? null : () => Get.back(result: spec),
        child: Opacity(
          opacity: taken ? .5 : 1,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: c.tint, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(c.short,
                    style: jakarta(12, weight: FontWeight.w800, color: c.ink)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(spec.name,
                      style: jakarta(14, weight: FontWeight.w700))),
              if (taken)
                Text('Déjà ajoutée', style: jakarta(11, color: AppColors.muted))
              else
                const Sym(Symbols.add_rounded,
                    size: 20, color: AppColors.forest),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Résultat de la fiche de modification.
class _CropEdit {
  const _CropEdit(
      {this.variety = '',
      this.share = 0,
      this.remove = false,
      this.change = false});
  final String variety;
  final int share;
  final bool remove;
  final bool change;
}

/// Modifier une culture : variété, part en %, changer de culture, ou la retirer.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.crop, required this.others});
  final Crop crop;

  /// Somme des parts des autres cultures de la saison.
  final int others;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _variety = TextEditingController(text: widget.crop.variety);
  late final _share = TextEditingController(text: '${widget.crop.share}');

  int get _s => (int.tryParse(_share.text) ?? 0).clamp(0, 100);
  int get _rest => (100 - widget.others).clamp(0, 100);

  @override
  void initState() {
    super.initState();
    _share.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _variety.dispose();
    _share.dispose();
    super.dispose();
  }

  _CropEdit _result({bool change = false}) =>
      _CropEdit(variety: _variety.text.trim(), share: _s, change: change);

  Widget _box(String label, Widget field) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  jakarta(10, weight: FontWeight.w700, color: AppColors.muted)),
          field,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.crop;
    final suggestions =
        CropCatalog.byName(c.name)?.varieties ?? const <String>[];
    return _sheet(
      context,
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: c.tint, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(c.short,
                      style:
                          jakarta(14, weight: FontWeight.w800, color: c.ink)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(c.name,
                        style: jakarta(18,
                            weight: FontWeight.w800, tracking: -.02))),
                Chip2(
                  label: 'Changer',
                  icon: Symbols.swap_horiz_rounded,
                  bg: AppColors.sage,
                  fg: AppColors.forest,
                  onTap: () => Get.back(result: _result(change: true)),
                ),
              ]),
              const SizedBox(height: 14),
              _box(
                'VARIÉTÉ (FACULTATIF)',
                TextField(
                  controller: _variety,
                  textCapitalization: TextCapitalization.sentences,
                  style: jakarta(16, weight: FontWeight.w700),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText:
                        'Ex. ${suggestions.firstOrNull ?? 'nom de la variété'}',
                    hintStyle: jakarta(16,
                        weight: FontWeight.w600, color: AppColors.faint),
                  ),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final v in suggestions)
                    Chip2(
                      label: v,
                      bg: AppColors.white(.7),
                      fg: AppColors.forest,
                      onTap: () => _variety.text = v,
                    ),
                ]),
              ],
              const SizedBox(height: 10),
              _box(
                'PART DE LA PARCELLE',
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _share,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3)
                      ],
                      style: jakarta(24, weight: FontWeight.w800),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        suffixText: ' %',
                        suffixStyle: jakarta(18,
                            weight: FontWeight.w700, color: AppColors.muted),
                        hintText: '0',
                        hintStyle: jakarta(24,
                            weight: FontWeight.w800, color: AppColors.faint),
                      ),
                    ),
                  ),
                  if (_s != _rest)
                    Chip2(
                      label: 'Compléter · $_rest %',
                      bg: AppColors.lime,
                      fg: AppColors.forest,
                      onTap: () => _share.text = '$_rest',
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FlatButton(
                    label: 'Retirer',
                    icon: Symbols.delete_rounded,
                    bg: AppColors.redSoft,
                    fg: AppColors.redInk,
                    height: 50,
                    radius: 16,
                    size: 14,
                    weight: FontWeight.w800,
                    onTap: () =>
                        Get.back(result: const _CropEdit(remove: true)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FlatButton(
                    label: 'Enregistrer',
                    icon: Symbols.check_rounded,
                    iconColor: AppColors.lime,
                    bg: AppColors.forest,
                    fg: Colors.white,
                    height: 50,
                    radius: 16,
                    weight: FontWeight.w800,
                    onTap: () => Get.back(result: _result()),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }
}
