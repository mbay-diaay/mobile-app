import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';

class Producer {
  const Producer({
    required this.initials,
    required this.name,
    required this.village,
    required this.age,
    required this.tint,
    this.code = 'PR-00000',
    this.phone = '+221 76 777 10 66',
    this.sex = 'Femme',
    this.org = 'GIE Bokk Jom Mboro',
    this.isNew = false,
    this.registeredAgo = Duration.zero,
    this.createdAt,
    this.archived = false,
    this.remoteId,
  });

  final String initials;
  final String name;
  final String village;
  final int age;
  final Color tint;
  final String code;
  final String phone;
  final String sex;
  final String org;

  /// Fiche créée pendant la session (pas encore envoyée).
  final bool isNew;

  /// Fiches de test : ancienneté de l'enregistrement par rapport au lancement de l'app.
  final Duration registeredAgo;

  /// Fiches créées pendant la session : date réelle de création.
  final DateTime? createdAt;

  /// Fiche archivée : masquée des listes, restaurable.
  final bool archived;

  /// Identifiant côté API (null tant que la fiche n'a pas été envoyée).
  final String? remoteId;

  Producer copyWith({
    String? initials,
    String? name,
    String? village,
    int? age,
    String? phone,
    String? sex,
    String? org,
    bool? archived,
    String? code,
    bool? isNew,
    String? remoteId,
    DateTime? createdAt,
  }) =>
      Producer(
        initials: initials ?? this.initials,
        name: name ?? this.name,
        village: village ?? this.village,
        age: age ?? this.age,
        tint: tint,
        code: code ?? this.code,
        phone: phone ?? this.phone,
        sex: sex ?? this.sex,
        org: org ?? this.org,
        isNew: isNew ?? this.isNew,
        registeredAgo: registeredAgo,
        createdAt: createdAt ?? this.createdAt,
        archived: archived ?? this.archived,
        remoteId: remoteId ?? this.remoteId,
      );

  /// Date d'enregistrement de la fiche.
  DateTime get registeredAt =>
      createdAt ?? MockData.launchedAt.subtract(registeredAgo);

  String get subtitle => age > 0 ? '$village · $age ans' : village;
}

class TodoItem {
  const TodoItem(this.icon, this.bg, this.ink, this.title, this.subtitle,
      {this.isPlot = false});
  final IconData icon;
  final Color bg;
  final Color ink;
  final String title;
  final String subtitle;
  final bool isPlot;
}

class SyncIssue {
  const SyncIssue(this.icon, this.title, this.owner, this.detail,
      {this.field = 'Téléphone', this.value = '+221 77 123 456'});
  final IconData icon;
  final String title;
  final String owner;
  final String detail;
  final String field;
  final String value;
}

class PendingItem {
  const PendingItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class Plot {
  const Plot(this.code, this.area, this.crops, this.status, this.statusBg,
      this.statusInk,
      {this.remoteId, this.areaHa = 0, this.lat, this.lng});
  final String code;
  final String area;
  final String crops;
  final String status;
  final Color statusBg;
  final Color statusInk;

  /// Identifiant côté API (null tant que la parcelle n'est pas envoyée).
  final String? remoteId;

  /// Surface en hectares et point central (l'API ne garde pas le contour).
  final double areaHa;
  final double? lat;
  final double? lng;

  Plot withRemoteId(String id) =>
      Plot(code, area, crops, status, statusBg, statusInk,
          remoteId: id, areaHa: areaHa, lat: lat, lng: lng);
}

class Crop {
  Crop(this.short, this.name, this.variety, this.tint, this.ink, this.bar,
      this.share);
  String short;
  String name;
  String variety;
  Color tint;
  Color ink;
  Color bar;

  /// Part de la parcelle, en %.
  int share;

  /// Identifiant côté API (null tant que la culture n'est pas envoyée).
  String? remoteId;

  Crop copy() =>
      Crop(short, name, variety, tint, ink, bar, share)..remoteId = remoteId;
}

abstract final class MockData {
  /// Repère des dates des fiches de test (« il y a 2 h », « hier »…).
  static final launchedAt = DateTime.now();

  static const tints = [
    AppColors.lime,
    AppColors.amberSoft,
    AppColors.blueSoft,
    AppColors.purpleSoft
  ];

  static const producers = [
    Producer(
        initials: 'SN',
        name: 'Samba Ndiaye',
        village: 'Mboro',
        age: 26,
        tint: AppColors.lime,
        code: 'PR-00002',
        registeredAgo: Duration(days: 21, hours: 2),
        sex: 'Homme'),
    Producer(
        initials: 'AS',
        name: 'Abdoulaye Seck',
        village: 'Mboro',
        age: 55,
        tint: AppColors.amberSoft,
        code: 'PR-00003',
        registeredAgo: Duration(days: 16, hours: 5),
        sex: 'Homme'),
    Producer(
        initials: 'SW',
        name: 'Saliou Wade',
        village: 'Mboro',
        age: 71,
        tint: AppColors.blueSoft,
        code: 'PR-00004',
        registeredAgo: Duration(days: 12, hours: 1),
        sex: 'Homme'),
    Producer(
        initials: 'SN',
        name: 'Sokhna Ndoye',
        village: 'Mboro',
        age: 65,
        tint: AppColors.purpleSoft,
        code: 'PR-00005',
        registeredAgo: Duration(days: 9, hours: 4)),
    Producer(
        initials: 'MK',
        name: 'Mamadou Kane',
        village: 'Mboro',
        age: 35,
        tint: AppColors.lime,
        code: 'PR-00006',
        registeredAgo: Duration(days: 6, hours: 3),
        sex: 'Homme'),
    Producer(
        initials: 'SS',
        name: 'Seynabou Seck',
        village: 'Mboro',
        age: 61,
        tint: AppColors.amberSoft,
        code: 'PR-00007',
        registeredAgo: Duration(days: 4, hours: 2)),
    Producer(
        initials: 'MD',
        name: 'Maïmouna Diouf',
        village: 'Mboro',
        age: 44,
        tint: AppColors.amberSoft,
        code: 'PR-00008',
        registeredAgo: Duration(days: 3, hours: 6)),
    Producer(
        initials: 'BD',
        name: 'Bineta Diop',
        village: 'Mboro',
        age: 38,
        tint: AppColors.blueSoft,
        code: 'PR-00009',
        registeredAgo: Duration(days: 1, hours: 6)),
    Producer(
        initials: 'KC',
        name: 'Khady Cissé',
        village: 'Diogo',
        age: 49,
        tint: AppColors.purpleSoft,
        code: 'PR-00010',
        registeredAgo: Duration(days: 1, hours: 3)),
    Producer(
        initials: 'AB',
        name: 'Aliou Ba',
        village: 'Mboro',
        age: 59,
        tint: AppColors.lime,
        code: 'PR-00011',
        registeredAgo: Duration(hours: 2, minutes: 20),
        sex: 'Homme'),
    // Fiches supplémentaires pour l'historique daté de l'accueil.
    Producer(
        initials: 'FS',
        name: 'Fatou Sarr',
        village: 'Mboro',
        age: 33,
        tint: AppColors.blueSoft,
        code: 'PR-00012',
        registeredAgo: Duration(minutes: 40)),
    Producer(
        initials: 'OF',
        name: 'Ousmane Fall',
        village: 'Diogo',
        age: 47,
        tint: AppColors.amberSoft,
        code: 'PR-00013',
        sex: 'Homme',
        registeredAgo: Duration(hours: 1, minutes: 15)),
    Producer(
        initials: 'AG',
        name: 'Aminata Gueye',
        village: 'Mboro',
        age: 29,
        tint: AppColors.purpleSoft,
        code: 'PR-00014',
        registeredAgo: Duration(hours: 4, minutes: 5)),
    Producer(
        initials: 'MS',
        name: 'Modou Sow',
        village: 'Darou Khoudoss',
        age: 52,
        tint: AppColors.lime,
        code: 'PR-00015',
        sex: 'Homme',
        registeredAgo: Duration(days: 1, hours: 1)),
    Producer(
        initials: 'NF',
        name: 'Ndeye Faye',
        village: 'Diogo',
        age: 41,
        tint: AppColors.blueSoft,
        code: 'PR-00016',
        registeredAgo: Duration(days: 2, hours: 2)),
    Producer(
        initials: 'CT',
        name: 'Cheikh Thiam',
        village: 'Mboro',
        age: 63,
        tint: AppColors.amberSoft,
        code: 'PR-00017',
        sex: 'Homme',
        registeredAgo: Duration(days: 2, hours: 5)),
    Producer(
        initials: 'AD',
        name: 'Awa Dieng',
        village: 'Fass Boye',
        age: 36,
        tint: AppColors.purpleSoft,
        code: 'PR-00018',
        registeredAgo: Duration(days: 5, hours: 1)),
    Producer(
        initials: 'IM',
        name: 'Ibou Mbaye',
        village: 'Diogo',
        age: 58,
        tint: AppColors.lime,
        code: 'PR-00019',
        sex: 'Homme',
        registeredAgo: Duration(days: 8, hours: 3)),
  ];

  static final recent = [producers[3], producers[6], producers[7]];

  static const todos = [
    TodoItem(Symbols.wc_rounded, AppColors.redSoft, AppColors.redInk,
        'Sexe incohérent avec le numéro de CNI', 'Seynabou Seck · Mboro'),
    TodoItem(Symbols.badge_rounded, AppColors.amberSoft, AppColors.amberInk,
        'CNI incomplète', 'Sokhna Diallo · Mboro'),
    TodoItem(Symbols.call_rounded, AppColors.redSoft, AppColors.redInk,
        'Téléphone invalide', 'Malick Kane · Mboro'),
    TodoItem(Symbols.badge_rounded, AppColors.amberSoft, AppColors.amberInk,
        'CNI incomplète', 'Seynabou Sy · Mboro'),
    TodoItem(Symbols.wc_rounded, AppColors.redSoft, AppColors.redInk,
        'Sexe incohérent avec le numéro de CNI', 'Ndèye Sy · Mboro'),
    TodoItem(Symbols.pentagon_rounded, AppColors.blueSoft, AppColors.blueInk,
        'Contour à reprendre', 'PA-0021 · Aliou Ndoye',
        isPlot: true),
    TodoItem(Symbols.pentagon_rounded, AppColors.blueSoft, AppColors.blueInk,
        'Contour à reprendre', 'PA-0023 · Coumba Wade',
        isPlot: true),
  ];

  static const syncIssues = [
    SyncIssue(Symbols.call_rounded, 'Téléphone non conforme', 'Awa Sow',
        'Le numéro a 8 chiffres au lieu de 9.'),
    SyncIssue(Symbols.content_copy_rounded, 'Doublon signalé', 'Moussa Fall',
        'Une fiche avec la même CNI existe déjà (PR-00045).',
        field: 'N° de CNI', value: '1 751 1990 01234'),
  ];

  static const pending = [
    PendingItem(Symbols.person_add_rounded, 'Nouvelle fiche · Coumba Ndiaye'),
    PendingItem(Symbols.pentagon_rounded, 'Parcelle relevée · PA-0034'),
    PendingItem(Symbols.photo_camera_rounded, 'Photo · Coumba Ndiaye'),
  ];

  static const plots = [
    Plot('PA-0006', '0,43 ha', 'Carotte, Aubergine', 'Relevée',
        AppColors.blueSoft, AppColors.blueInk),
    Plot('PA-0012', '0,20 ha', 'Oignon', 'Validée', AppColors.lime,
        AppColors.forest),
  ];

  static const villages = [
    'Mboro',
    'Diogo',
    'Darou Khoudoss',
    'Fass Boye',
    'Notto Gouye Diama'
  ];
  static const orgs = ['Aucune', 'GIE Bokk Jom Mboro', 'GIE Jappo Diogo'];

  /// Contour « tous les angles » de l'écran 16a, en coordonnées 324×380.
  static const surveyCorners = [
    Offset(70, 150),
    Offset(210, 135),
    Offset(265, 200),
    Offset(245, 320),
    Offset(115, 330),
    Offset(55, 240),
  ];
}
