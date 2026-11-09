import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/network_service.dart';
import '../../services/producers_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/layout.dart';
import '../../widgets/senegal_flag.dart';

/// 11 · Nouveau producteur, et 12 · suggestion de doublon (panneau qui monte).
///
/// Avec une fiche en argument, le même formulaire sert à la **modifier** : champs
/// préremplis, sans CNI ni photos, et une confirmation avant d'abandonner des
/// changements non enregistrés. Il renvoie alors la fiche mise à jour.
class NewProducerController extends GetxController {
  final Producer? editing =
      Get.arguments is Producer ? Get.arguments as Producer : null;
  bool get isEdit => editing != null;
  final dirty = false.obs;
  String _initial = '';

  final first = TextEditingController();
  final last = TextEditingController();
  final age = TextEditingController();
  final phone = TextEditingController();
  final cni = TextEditingController();

  final sex = (-1).obs; // 0 Femme, 1 Homme
  final village = MockData.villages.first.obs;
  final org = MockData.orgs.first.obs;

  /// Photos de la CNI (chemins locaux), toutes deux obligatoires.
  final cniFront = RxnString();
  final cniBack = RxnString();
  final _formOk = false.obs;
  final _picker = ImagePicker();
  final saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final e = editing;
    if (e != null) {
      final parts = e.name.split(' ');
      first.text = parts.first;
      last.text = parts.skip(1).join(' ');
      sex.value = e.sex == 'Homme' ? 1 : 0;
      age.text = e.age > 0 ? '${e.age}' : '';
      phone.text = e.phone
          .replaceAll(RegExp(r'\D'), '')
          .replaceFirst(RegExp(r'^221'), '');
      village.value = e.village;
      org.value = e.org;
      _formOk.value = true;
      _initial = _snapshot();
      for (final c in [first, last, age, phone]) {
        c.addListener(_recompute);
      }
      ever(sex, (_) => _recompute());
      ever(village, (_) => _recompute());
      ever(org, (_) => _recompute());
    }
    for (final c in [first, last]) {
      c.addListener(() => _formOk.value =
          first.text.trim().isNotEmpty && last.text.trim().isNotEmpty);
    }
  }

  String _snapshot() => [
        first.text.trim(),
        last.text.trim(),
        age.text,
        phone.text,
        sex.value,
        village.value,
        org.value
      ].join('|');
  void _recompute() => dirty.value = _snapshot() != _initial;

  /// Fermeture : en modification, on confirme avant de perdre des changements.
  Future<void> close() async {
    if (isEdit && dirty.value) {
      final discard = await confirmSheet(
        title: 'Abandonner les modifications ?',
        message:
            "Les changements apportés à la fiche ne seront pas enregistrés.",
        confirmLabel: 'Abandonner',
        cancelLabel: 'Continuer',
        icon: Symbols.edit_off_rounded,
        destructive: true,
      );
      if (!discard) return;
    }
    Get.back();
  }

  bool get hasCni => cniFront.value != null && cniBack.value != null;
  bool get canSave => _formOk.value && (isEdit ? dirty.value : hasCni);

  /// Ouvre l'appareil photo (caméra arrière) pour une face de la CNI.
  /// Sans caméra (simulateur), on se rabat sur la photothèque.
  Future<void> takeCni({required bool front}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } on PlatformException {
      showToast('Appareil photo indisponible · choix dans la photothèque',
          icon: Symbols.no_photography_rounded);
      try {
        shot = await _picker.pickImage(
            source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      } on PlatformException {
        showToast("Accès aux photos refusé. Autorisez-le dans les réglages.",
            icon: Symbols.block_rounded);
      }
    }
    if (shot == null) return;
    HapticFeedback.lightImpact();
    (front ? cniFront : cniBack).value = shot.path;
  }

  Producer? _findDuplicate() =>
      Get.find<SessionService>().producers.firstWhereOrNull(
            (p) =>
                p.name.toLowerCase() ==
                    '${first.text.trim()} ${last.text.trim()}'.toLowerCase() &&
                p.village == village.value,
          );

  Future<void> _saveEdit() async {
    final e = editing!;
    final clash = Get.find<SessionService>().producers.any((p) =>
        p.code != e.code &&
        p.name.toLowerCase() ==
            '${first.text.trim()} ${last.text.trim()}'.trim().toLowerCase() &&
        p.village == village.value);
    if (clash) {
      final go = await confirmSheet(
        title: 'Une fiche existe déjà',
        message:
            'Un autre producteur porte déjà ce nom à ${village.value}. Enregistrer quand même ?',
        confirmLabel: 'Enregistrer',
        icon: Symbols.content_copy_rounded,
      );
      if (!go) return;
    }
    saving.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    final updated = Get.find<SessionService>().updateProducer(
      e,
      first: _cap(first.text),
      last: last.text.trim().isEmpty ? '' : _cap(last.text),
      village: village.value,
      org: org.value,
      sex: sex.value == 1 ? 'Homme' : 'Femme',
      age: int.tryParse(age.text),
      phone: phone.text,
    );
    saving.value = false;
    Get.back(result: updated);
  }

  Future<void> save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (isEdit) return _saveEdit();
    final dup = _findDuplicate();
    if (dup != null) {
      final same = await Get.bottomSheet<bool>(
        _DuplicateSheet(p: dup),
        isScrollControlled: true,
        barrierColor: const Color(0x8C0A140F),
        enterBottomSheetDuration: const Duration(milliseconds: 520),
        exitBottomSheetDuration: Motion.medium,
      );
      if (same == null) return;
      if (same) {
        Get.offNamed(Routes.producer, arguments: dup);
        return;
      }
    }
    saving.value = true;
    final firstName = _cap(first.text);
    final lastName = _cap(last.text);
    var synced = false;
    String? serverCode;
    String? serverId;

    // Si session API ouverte + réseau : le serveur valide la création (dernier mot).
    final producersApi = Get.find<ProducersService>();
    if (producersApi.canReachServer) {
      try {
        final remote = await producersApi.create(
          firstName: firstName,
          lastName: lastName,
          village: village.value,
          phone: phone.text,
          cni: cni.text.trim().isEmpty ? null : cni.text.trim(),
        );
        if (remote != null) {
          synced = true;
          serverCode = remote['code'] as String?;
          serverId = remote['id'] as String?;
          if (serverId != null && hasCni) {
            if (cniFront.value != null) {
              await producersApi.uploadCniPhoto(serverId, cniFront.value!);
            }
            if (cniBack.value != null) {
              await producersApi.uploadCniPhoto(serverId, cniBack.value!);
            }
          }
        }
      } catch (_) {
        // Hors ligne / erreur serveur : on garde la fiche locale en attente.
      }
    }

    final p = Get.find<SessionService>().addProducer(
      first: firstName,
      last: lastName,
      village: village.value,
      org: org.value,
      sex: sex.value == 1 ? 'Homme' : 'Femme',
      age: int.tryParse(age.text),
      phone: phone.text,
      cniPhotos: hasCni,
      code: serverCode,
      synced: synced,
    );
    saving.value = false;
    Get.offNamed(Routes.success, arguments: {
      'title': 'Fiche enregistrée',
      'sub': synced
          ? '${p.name} · ${p.code} · statut « recensé ».\nEnregistrée sur le serveur.'
          : '${p.name} · ${p.code} · statut « recensé ».\nElle partira au prochain envoi.',
      'cta': 'Relever sa parcelle',
      'route': Routes.survey,
      'args': p,
    });
  }

  String _cap(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  void onClose() {
    for (final c in [first, last, age, phone, cni]) {
      c.dispose();
    }
    super.onClose();
  }
}

class NewProducerView extends GetView<NewProducerController> {
  const NewProducerView({super.key});

  @override
  Widget build(BuildContext context) {
    final net = Get.find<NetworkService>();
    var i = 0;
    Widget item(Widget w) => FadeSlideIn(
        delay: Motion.stagger(i++, base: 120, step: 45),
        offset: const Offset(0, 24),
        child: w);

    final c = controller;
    // En modification, le retour système (ou le geste) demande aussi confirmation.
    return Obx(() => PopScope(
          canPop: !(c.isEdit && c.dirty.value),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) c.close();
          },
          child: _scaffold(net, item),
        ));
  }

  Widget _scaffold(NetworkService net, Widget Function(Widget) item) {
    return StatusBarStyle(
      dark: false,
      child: Scaffold(
        body: SafeArea(
          child: FillScroll(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  item(Row(children: [
                    SquareIconButton(
                        icon: Symbols.close_rounded, onTap: controller.close),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            controller.isEdit
                                ? 'Modifier la fiche'
                                : 'Nouveau producteur',
                            style: display(22))),
                  ])),
                  const SizedBox(height: 11),
                  item(Align(
                    alignment: Alignment.centerLeft,
                    child: controller.isEdit
                        ? Chip2(
                            label: '${controller.editing!.code} · modification',
                            icon: Symbols.edit_rounded,
                            bg: AppColors.forest,
                            fg: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          )
                        : Obx(() => Chip2(
                              label: net.online.value
                                  ? 'En ligne · statut « recensé »'
                                  : 'Sans réseau · statut « recensé »',
                              icon: net.online.value
                                  ? Symbols.wifi_rounded
                                  : Symbols.wifi_off_rounded,
                              bg: AppColors.forest,
                              fg: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            )),
                  )),
                  const SizedBox(height: 11),
                  item(Row(children: [
                    Expanded(
                        child: _Field(
                            label: 'Prénom *',
                            controller: controller.first,
                            caps: true)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Field(
                            label: 'Nom *',
                            controller: controller.last,
                            caps: true)),
                  ])),
                  const SizedBox(height: 11),
                  item(Obx(() => SegmentedPill(
                        labels: const ['Femme', 'Homme'],
                        index: controller.sex.value,
                        onChanged: (v) => controller.sex.value = v,
                        dark: true,
                        fontSize: 13,
                        vPad: 11,
                      ))),
                  const SizedBox(height: 11),
                  item(Row(children: [
                    SizedBox(
                        width: 90,
                        child: _Field(
                            label: 'Âge',
                            controller: controller.age,
                            number: true,
                            max: 3)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Field(
                      label: 'Téléphone',
                      controller: controller.phone,
                      number: true,
                      max: 9,
                      prefix: '+221',
                      hint: '77 123 45 67',
                      leading: const SenegalFlag(size: Size(18, 12)),
                    )),
                  ])),
                  const SizedBox(height: 11),
                  item(Obx(() => _Select(
                      label: 'Village *',
                      value: controller.village.value,
                      options: MockData.villages,
                      onPick: controller.village.call))),
                  const SizedBox(height: 11),
                  item(Obx(() => _Select(
                      label: 'Organisation',
                      value: controller.org.value,
                      options: MockData.orgs,
                      onPick: controller.org.call))),
                  const SizedBox(height: 11),
                  if (!controller.isEdit) ...[
                    item(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            label: 'N° de CNI (facultatif)',
                            controller: controller.cni,
                            number: true,
                            max: 13,
                            hint: '13 chiffres',
                            trailing: const Sym(Symbols.lock_rounded,
                                size: 20, color: AppColors.forest),
                            obscure: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
                            child: Text(
                                'Envoyée chiffrée. Elle ne reste pas lisible sur le téléphone.',
                                style: jakarta(10, color: AppColors.muted)),
                          ),
                        ])),
                    const SizedBox(height: 11),
                    item(const _CniPhotos()),
                  ],
                  const Spacer(),
                  const SizedBox(height: 16),
                  item(Obx(() => SwipeCta.dark(
                        label: 'Glissez pour enregistrer',
                        busyLabel: 'Enregistrement…',
                        onConfirm: controller.canSave ? controller.save : null,
                      ))),
                  if (!controller.isEdit) ...[
                    const SizedBox(height: 8),
                    Text(
                        'Astuce prototype : « Aliou Ba » à Mboro déclenche la suggestion de doublon.',
                        textAlign: TextAlign.center,
                        style: jakarta(10, color: AppColors.muted)),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}

/// Champ blanc arrondi sans bordure, libellé au-dessus de la valeur.
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.number = false,
    this.max,
    this.prefix,
    this.leading,
    this.hint,
    this.trailing,
    this.caps = false,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool number;
  final int? max;
  final String? prefix;

  /// Élément fixe devant la saisie (drapeau de l'indicatif…).
  final Widget? leading;
  final String? hint;
  final Widget? trailing;
  final bool caps;
  final bool obscure;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _focus.requestFocus,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _focus.hasFocus ? AppColors.forest : Colors.transparent,
                width: 2),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: jakarta(10,
                            weight: FontWeight.w700, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Row(children: [
                        if (widget.leading != null) ...[
                          widget.leading!,
                          const SizedBox(width: 6)
                        ],
                        // Indicatif fixe : toujours affiché, jamais doublé par l'indication.
                        if (widget.prefix != null) ...[
                          Text(widget.prefix!,
                              style: jakarta(14, weight: FontWeight.w700)),
                          const SizedBox(width: 6)
                        ],
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            obscureText: widget.obscure,
                            textCapitalization: widget.caps
                                ? TextCapitalization.words
                                : TextCapitalization.none,
                            keyboardType: widget.number
                                ? TextInputType.number
                                : TextInputType.name,
                            inputFormatters: [
                              if (widget.number)
                                FilteringTextInputFormatter.digitsOnly,
                              if (widget.max != null)
                                LengthLimitingTextInputFormatter(widget.max),
                            ],
                            style: jakarta(14, weight: FontWeight.w700),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: widget.hint,
                              hintStyle: jakarta(14, color: AppColors.faint),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
            ),
            if (widget.trailing != null) widget.trailing!,
          ]),
        ),
      );
}

class _Select extends StatelessWidget {
  const _Select(
      {required this.label,
      required this.value,
      required this.options,
      required this.onPick});
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: .98,
        onTap: () async {
          final v = await Get.bottomSheet<String>(_OptionsSheet(
              title: label.replaceAll(' *', ''),
              options: options,
              selected: value));
          if (v != null) onPick(v);
        },
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: jakarta(10,
                            weight: FontWeight.w700, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      child: Text(value,
                          key: ValueKey(value),
                          style: jakarta(14, weight: FontWeight.w700)),
                    ),
                  ]),
            ),
            const Sym(Symbols.expand_more_rounded),
          ]),
        ),
      );
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet(
      {required this.title, required this.options, required this.selected});
  final String title;
  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: SafeArea(
          top: false,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Handle(),
                const SizedBox(height: 12),
                Text(title, style: display(22)),
                const SizedBox(height: 12),
                for (final (i, o) in options.indexed)
                  FadeSlideIn(
                    delay: Motion.stagger(i, base: 60, step: 40),
                    child: Pressable(
                      onTap: () => Get.back(result: o),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              o == selected ? AppColors.forest : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(o,
                                style: jakarta(14,
                                    weight: FontWeight.w700,
                                    color: o == selected
                                        ? AppColors.lime
                                        : AppColors.ink)),
                          ),
                          if (o == selected)
                            const Sym(Symbols.check_rounded,
                                size: 20, color: AppColors.lime),
                        ]),
                      ),
                    ),
                  ),
              ]),
        ),
      );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
                color: AppColors.handle,
                borderRadius: BorderRadius.circular(3))),
      );
}

/// 12 · « Cette personne existe peut-être déjà »
class _DuplicateSheet extends StatelessWidget {
  const _DuplicateSheet({required this.p});
  final Producer p;

  @override
  Widget build(BuildContext context) {
    final him = p.sex == 'Homme';
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 200),
                  scale: .3,
                  offset: Offset.zero,
                  curve: Curves.elasticOut,
                  duration: Duration(milliseconds: 1000),
                  child: IconTile(Symbols.group_rounded,
                      size: 52,
                      radius: 18,
                      bg: AppColors.amberSoft,
                      fg: AppColors.amberInk,
                      iconSize: 28,
                      fill: true),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 260),
                child: Text('Cette personne existe peut-être déjà',
                    style: display(22, height: 1.1)),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Text('Même nom et même village.',
                    style: jakarta(12, color: AppColors.muted)),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 360),
                scale: .9,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.forest, width: 2),
                  ),
                  child: Row(children: [
                    IconTile(Symbols.person_rounded,
                        bg: p.tint, fg: AppColors.forest),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: jakarta(15, weight: FontWeight.w800)),
                            Text('${p.age} ans · ${p.village} · tél. …28',
                                style: jakarta(11, color: AppColors.muted)),
                          ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 420),
                child: FlatButton(
                  label: him ? "Oui, c'est lui" : "Oui, c'est elle",
                  icon: Symbols.check_rounded,
                  iconColor: AppColors.lime,
                  bg: AppColors.forest,
                  fg: Colors.white,
                  height: 56,
                  size: 15,
                  weight: FontWeight.w800,
                  onTap: () => Get.back(result: true),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 470),
                child: FlatButton(
                    label: "Non, c'est une autre personne",
                    onTap: () => Get.back(result: false)),
              ),
              const SizedBox(height: 12),
              Text("La CNI sera comparée par le serveur à l'envoi.",
                  textAlign: TextAlign.center,
                  style: jakarta(10, color: AppColors.muted)),
            ]),
      ),
    );
  }
}

/// Recto et verso de la CNI, pris à l'appareil photo. Les deux sont obligatoires.
class _CniPhotos extends GetView<NewProducerController> {
  const _CniPhotos();

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Row(children: [
            Text('Photos de la CNI',
                style: jakarta(10,
                    weight: FontWeight.w700, color: AppColors.muted)),
            const Spacer(),
            Obx(() {
              final n = (controller.cniFront.value != null ? 1 : 0) +
                  (controller.cniBack.value != null ? 1 : 0);
              return Text('$n / 2 · avec accord',
                  style: jakarta(10,
                      weight: FontWeight.w700,
                      color: n == 2 ? AppColors.forest : AppColors.muted));
            }),
          ]),
        ),
        Row(children: [
          Expanded(
              child: Obx(() => _CniSlot(
                  label: 'Recto',
                  path: controller.cniFront.value,
                  onTap: () => controller.takeCni(front: true)))),
          const SizedBox(width: 10),
          Expanded(
              child: Obx(() => _CniSlot(
                  label: 'Verso',
                  path: controller.cniBack.value,
                  onTap: () => controller.takeCni(front: false)))),
        ]),
      ]);
}

/// Une face de la CNI : cadre pointillé vide, ou aperçu de la photo (toucher pour reprendre).
class _CniSlot extends StatelessWidget {
  const _CniSlot(
      {required this.label, required this.path, required this.onTap});
  final String label;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty =
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Sym(Symbols.photo_camera_rounded,
          size: 24, color: AppColors.forest),
      const SizedBox(height: 4),
      Text(label, style: jakarta(13, weight: FontWeight.w800)),
      Text('Toucher pour photographier',
          style: jakarta(9, color: AppColors.muted)),
    ]);
    return Pressable(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.58, // format carte d'identité
        child: AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Motion.spring),
                child: c),
          ),
          child: path == null
              ? CustomPaint(
                  key: const ValueKey('empty'),
                  painter:
                      DashedBorderPainter(color: AppColors.faint, radius: 16),
                  child: Center(child: empty),
                )
              : ClipRRect(
                  key: ValueKey(path),
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(path!), fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x99000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 6,
                      right: 8,
                      child: Row(children: [
                        Text(label,
                            style: jakarta(12,
                                weight: FontWeight.w800, color: Colors.white)),
                        const Spacer(),
                        const Sym(Symbols.refresh_rounded,
                            size: 16, color: Colors.white),
                      ]),
                    ),
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: IconTile(Symbols.check_rounded,
                          size: 22, radius: 8, iconSize: 15),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }
}
