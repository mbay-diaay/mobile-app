import 'package:flutter/widgets.dart' show IconData;
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/crop_catalog.dart';
import '../data/mock_data.dart';

/// Compte de test accepté à l'activation (connexion simulée, sans serveur).
class TestAccount {
  const TestAccount(
      this.phone, this.name, this.fullName, this.initials, this.scoop);
  final String phone;
  final String name;
  final String fullName;
  final String initials;
  final String scoop;
}

/// État partagé du prototype. Tout ce qui est créé (fiches, parcelles,
/// cultures, corrections) est gardé en mémoire le temps de la session :
/// un redémarrage repart des données de test. Seule l'activation du téléphone
/// (compte, PIN) est enregistrée, pour arriver directement au PIN au relancement.
class SessionService extends GetxService {
  static const defaultPin = '1234';
  static const maxAttempts = 3;

  /// Code SMS de test affiché à l'écran 02 (tout code à 6 chiffres reste accepté).
  static const testSmsCode = '482913';

  static const testAccounts = [
    TestAccount(
        '771234567', 'Ibrahima', 'Ibrahima Diagne', 'ID', 'And Liggey Mboro'),
    TestAccount('781112233', 'Awa', 'Awa Ndiaye', 'AN', 'Jappo Diogo'),
  ];

  final account = testAccounts.first.obs;
  String get technician => account.value.name;
  String get technicianFull => account.value.fullName;
  String get initials => account.value.initials;
  String get scoop => account.value.scoop;

  final pin = defaultPin.obs;
  final failedAttempts = 0.obs;

  /// Téléphone activé (étapes 01 à 04 terminées) : le démarrage mène au PIN.
  final activated = false.obs;

  static const _kActivated = 'activated';
  static const _kPhone = 'account_phone';
  static const _kPin = 'pin';
  late final SharedPreferences _prefs;

  /// Relit l'activation enregistrée, puis enregistre chaque changement de compte ou de PIN.
  Future<SessionService> init() async {
    _prefs = await SharedPreferences.getInstance();
    activated.value = _prefs.getBool(_kActivated) ?? false;
    final saved = findAccount(_prefs.getString(_kPhone) ?? '');
    if (saved != null) account.value = saved;
    pin.value = _prefs.getString(_kPin) ?? defaultPin;
    ever(account, (a) => _prefs.setString(_kPhone, a.phone));
    ever(pin, (p) => _prefs.setString(_kPin, p));
    return this;
  }

  /// Fin de l'activation (écran 04).
  void completeActivation() {
    activated.value = true;
    _prefs
      ..setBool(_kActivated, true)
      ..setString(_kPhone, account.value.phone)
      ..setString(_kPin, pin.value);
  }

  /// Révocation (écran 25) : le prochain démarrage repasse par l'activation.
  void revoke() {
    activated.value = false;
    failedAttempts.value = 0;
    pin.value = defaultPin;
    _prefs
      ..remove(_kActivated)
      ..remove(_kPhone)
      ..remove(_kPin);
  }

  final producers = <Producer>[...MockData.producers].obs;
  final recent = <Producer>[...MockData.recent].obs;
  final plots = <String, List<Plot>>{}.obs; // clé : code producteur

  /// Cultures déclarées par parcelle (clé : code parcelle) et par saison
  /// (0 = campagne horticole, 1 = contre-saison). Gardées en mémoire, hors ligne.
  final cropPlans = <String, Map<int, List<Crop>>>{
    'PA-0006': {
      0: [
        CropCatalog.byName('Carotte')!.toCrop(60),
        CropCatalog.byName('Aubergine')!.toCrop(40)
      ],
    },
    'PA-0012': {
      0: [CropCatalog.byName('Oignon')!.toCrop(100, 'Violet de Galmi')],
    },
  }.obs;
  final toFix = <SyncIssue>[...MockData.syncIssues].obs;
  final pending = <PendingItem>[...MockData.pending].obs;
  final todoCount = 8.obs;

  final createdToday = 4.obs;
  final surveyedToday = 1.obs;
  final cropsToday = 0.obs;

  int _nextProducer = 20;
  int _nextPlot = 35;

  /// Connexion simulée : renvoie le compte de test correspondant, ou null.
  TestAccount? findAccount(String phone) =>
      testAccounts.firstWhereOrNull((a) => a.phone == phone);

  void signIn(TestAccount a) => account.value = a;

  bool checkPin(String value) {
    if (value == pin.value) {
      failedAttempts.value = 0;
      return true;
    }
    failedAttempts.value++;
    return false;
  }

  bool get locked => failedAttempts.value >= maxAttempts;

  void visit(Producer p) {
    recent.removeWhere((x) => x.code == p.code);
    recent.insert(0, p);
    if (recent.length > 3) recent.removeRange(3, recent.length);
  }

  Producer addProducer({
    required String first,
    required String last,
    required String village,
    required String org,
    required String sex,
    int? age,
    String? phone,
    bool cniPhotos = false,
    String? code,
    bool synced = false,
  }) {
    final p = Producer(
      initials: '${first[0]}${last[0]}'.toUpperCase(),
      name: '$first $last',
      village: village,
      age: age ?? 0,
      tint: MockData.tints[producers.length % MockData.tints.length],
      code: code ?? 'PR-${(_nextProducer++).toString().padLeft(5, '0')}',
      phone: phone == null || phone.isEmpty ? '—' : '+221 $phone',
      sex: sex,
      org: org,
      isNew: !synced,
      createdAt: DateTime.now(),
    );
    producers.insert(0, p);
    visit(p);
    createdToday.value++;
    pending.add(
        PendingItem(Symbols.person_add_rounded, 'Nouvelle fiche · ${p.name}'));
    if (cniPhotos)
      pending.add(
          PendingItem(Symbols.badge_rounded, 'CNI recto + verso · ${p.name}'));
    return p;
  }

  /// Fiches visibles dans les listes (hors archivées).
  List<Producer> get activeProducers =>
      producers.where((p) => !p.archived).toList();
  List<Producer> get archivedProducers =>
      producers.where((p) => p.archived).toList();

  void _replace(Producer old, Producer updated) {
    final i = producers.indexWhere((x) => x.code == old.code);
    if (i >= 0) producers[i] = updated;
    final r = recent.indexWhere((x) => x.code == old.code);
    if (r >= 0) recent[r] = updated;
  }

  void _queue(IconData icon, String label) {
    if (!pending.any((x) => x.label == label))
      pending.add(PendingItem(icon, label));
  }

  /// Modifie la fiche (le code et la date d'enregistrement restent inchangés).
  Producer updateProducer(
    Producer old, {
    required String first,
    required String last,
    required String village,
    required String org,
    required String sex,
    int? age,
    String? phone,
  }) {
    final updated = old.copyWith(
      initials: '${first[0]}${last.isEmpty ? '' : last[0]}'.toUpperCase(),
      name: last.isEmpty ? first : '$first $last',
      village: village,
      org: org,
      sex: sex,
      age: age ?? 0,
      phone: phone == null || phone.isEmpty ? '—' : '+221 $phone',
    );
    _replace(old, updated);
    _queue(Symbols.edit_rounded, 'Modification · ${updated.name}');
    return updated;
  }

  /// Archive la fiche : elle quitte les listes, mais ses parcelles et cultures sont conservées.
  Producer archiveProducer(Producer p) {
    final updated = p.copyWith(archived: true);
    _replace(p, updated);
    recent.removeWhere((x) => x.code == p.code);
    _queue(Symbols.inventory_2_rounded, 'Archivage · ${p.name}');
    return updated;
  }

  Producer restoreProducer(Producer p) {
    final updated = p.copyWith(archived: false);
    _replace(p, updated);
    _queue(Symbols.unarchive_rounded, 'Restauration · ${p.name}');
    return updated;
  }

  List<Plot> plotsOf(Producer p) {
    final base = plots[p.code] ?? (p.isNew ? const <Plot>[] : MockData.plots);
    return [for (final pl in base) _withCrops(pl)];
  }

  /// La parcelle affiche les cultures réellement déclarées, toutes saisons confondues.
  Plot _withCrops(Plot pl) {
    final plan = cropPlans[pl.code];
    if (plan == null) return pl;
    final names = <String>{
      for (final s in plan.keys.toList()..sort())
        for (final c in plan[s]!)
          if (c.share > 0) c.name,
    };
    if (names.isEmpty) return pl;
    return Plot(pl.code, pl.area, names.join(', '), pl.status, pl.statusBg,
        pl.statusInk);
  }

  /// Copie de travail des cultures d'une parcelle pour une saison.
  List<Crop> cropsOf(String plotCode, int season) => [
        for (final c in cropPlans[plotCode]?[season] ?? const <Crop>[]) c.copy()
      ];

  String nextPlotCode() => 'PA-${(_nextPlot++).toString().padLeft(4, '0')}';

  void addPlot(Producer owner, Plot plot, double area) {
    plots[owner.code] = [plot, ...plotsOf(owner)];
    surveyedToday.value++;
    pending.add(PendingItem(
        Symbols.pentagon_rounded, 'Parcelle relevée · ${plot.code}'));
  }

  /// Enregistre les cultures de la parcelle (une liste par saison, les vides sont ignorées).
  void declareCrops(String plotCode, Map<int, List<Crop>> perSeason) {
    cropPlans[plotCode] = {
      for (final e in perSeason.entries)
        if (e.value.isNotEmpty) e.key: [for (final c in e.value) c.copy()],
    };
    cropsToday.value++;
    final label = 'Cultures · $plotCode';
    if (!pending.any((x) => x.label == label))
      pending.add(PendingItem(Symbols.potted_plant_rounded, label));
  }

  void resolveIssue(SyncIssue issue) {
    toFix.remove(issue);
    pending.add(PendingItem(issue.icon, 'Correction · ${issue.owner}'));
  }

  void markSent() => pending.clear();
}
