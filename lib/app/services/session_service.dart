import 'package:flutter/widgets.dart' show IconData;
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/crop_catalog.dart';
import '../data/mock_data.dart';
import 'auth_service.dart';
import 'api_client.dart';
import 'producer_repository.dart';

/// Technicien connecté (profil renvoyé par l'API).
class TestAccount {
  const TestAccount(
      this.email, this.name, this.fullName, this.initials, this.scoop);
  final String email;
  final String name;
  final String fullName;
  final String initials;
  final String scoop;

  /// Construit l'affichage (prénom, initiales) à partir du nom complet de l'API.
  factory TestAccount.fromUser(AuthUser u, {String scoop = ''}) {
    final parts =
        u.name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final first = parts.isEmpty ? u.email : parts.first;
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : (first.isEmpty ? '?' : first[0]);
    return TestAccount(u.email, first, u.name.isEmpty ? u.email : u.name,
        initials.toUpperCase(), scoop);
  }
}

/// État partagé du prototype. Tout ce qui est créé (fiches, parcelles,
/// cultures, corrections) est gardé en mémoire le temps de la session :
/// un redémarrage repart des données de test. Seule l'activation du téléphone
/// (compte, PIN) est enregistrée, pour arriver directement au PIN au relancement.
class SessionService extends GetxService {
  static const defaultPin = '1234';
  static const maxAttempts = 3;

  final account =
      const TestAccount('', 'Technicien', 'Technicien', 'T', '').obs;
  String get technician => account.value.name;
  String get technicianFull => account.value.fullName;
  String get initials => account.value.initials;
  String get scoop => account.value.scoop;

  final pin = defaultPin.obs;
  final failedAttempts = 0.obs;

  /// Téléphone activé (étapes 01 à 04 terminées) : le démarrage mène au PIN.
  final activated = false.obs;

  static const _kActivated = 'activated';
  static const _kEmail = 'account_email';
  static const _kName = 'account_name';
  static const _kScoop = 'account_scoop';
  static const _kPin = 'pin';
  late final SharedPreferences _prefs;

  /// Relit l'activation enregistrée, puis enregistre chaque changement de compte ou de PIN.
  Future<SessionService> init() async {
    _prefs = await SharedPreferences.getInstance();
    activated.value = _prefs.getBool(_kActivated) ?? false;
    final email = _prefs.getString(_kEmail);
    if (email != null) {
      account.value = TestAccount.fromUser(
          AuthUser(
              id: '',
              email: email,
              name: _prefs.getString(_kName) ?? '',
              role: ''),
          scoop: _prefs.getString(_kScoop) ?? '');
    }
    pin.value = _prefs.getString(_kPin) ?? defaultPin;
    ever(pin, (p) => _prefs.setString(_kPin, p));
    return this;
  }

  /// Fin de l'activation (écran 04).
  void completeActivation() {
    activated.value = true;
    _prefs
      ..setBool(_kActivated, true)
      ..setString(_kEmail, account.value.email)
      ..setString(_kName, account.value.fullName)
      ..setString(_kScoop, account.value.scoop)
      ..setString(_kPin, pin.value);
  }

  /// Révocation (écran 25) : le prochain démarrage repasse par l'activation.
  void revoke() {
    if (Get.isRegistered<AuthService>()) Get.find<AuthService>().logout();
    if (Get.isRegistered<ProducerRepository>()) {
      Get.find<ProducerRepository>().clearCache();
    }
    activated.value = false;
    failedAttempts.value = 0;
    pin.value = defaultPin;
    _prefs
      ..remove(_kActivated)
      ..remove(_kEmail)
      ..remove(_kName)
      ..remove(_kScoop)
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

  void signIn(TestAccount a) => account.value = a;

  /// Annuaire du cache local (instantané, fonctionne hors ligne).
  Future<void> restoreProducers() async {
    applyServerProducers(await Get.find<ProducerRepository>().cached());
  }

  /// Annuaire de l'API ; en cas d'échec (hors ligne…), on garde ce qui est déjà affiché.
  /// Renvoie null si tout va bien, sinon l'erreur.
  Future<ApiException?> refreshProducers() async {
    try {
      applyServerProducers(await Get.find<ProducerRepository>().fetch());
      return null;
    } on ApiException catch (e) {
      return e;
    }
  }

  /// Remplace l'annuaire de démonstration par celui de l'API ; les fiches créées sur
  /// cet appareil (pas encore envoyées) restent en tête.
  void applyServerProducers(List<Producer> server) {
    if (server.isEmpty) return;
    final local = producers.where((p) => p.isNew).toList();
    final archived = {
      for (final p in producers.where((p) => p.archived)) p.code
    };
    producers.assignAll([
      ...local,
      for (final p in server)
        archived.contains(p.code) ? p.copyWith(archived: true) : p,
    ]);
    recent.assignAll(producers.where((p) => !p.archived).take(3));
  }

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
    _pushCreate(p, first, last);
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
    _pushUpdate(updated, first, last, phone);
    return updated;
  }

  /// Envoie la nouvelle fiche à l'API. Hors ligne ou refusée : elle reste « en attente d'envoi ».
  Future<void> _pushCreate(Producer p, String first, String last) async {
    try {
      final data = await Get.find<ApiClient>().post('/producers', body: {
        'firstName': first,
        'lastName': last.isEmpty ? first : last,
        if (ProducerRepository.apiPhone(p.phone == '—' ? null : p.phone) !=
            null)
          'phone': ProducerRepository.apiPhone(p.phone),
        if (p.village.isNotEmpty) 'village': p.village,
      }) as Map<String, dynamic>;
      final sent = p.copyWith(
          code: (data['code'] ?? p.code).toString(),
          remoteId: data['id']?.toString(),
          isNew: false);
      _replace(p, sent);
      pending.removeWhere((x) =>
          x.label.endsWith('· ${p.name}') &&
          (x.label.startsWith('Nouvelle fiche')));
      // Le code vient de l'API : les parcelles suivent la fiche, puis partent à leur tour.
      if (sent.code != p.code && plots.containsKey(p.code)) {
        plots[sent.code] = plots.remove(p.code)!;
      }
      for (final pl in List<Plot>.of(plots[sent.code] ?? const <Plot>[])) {
        await _pushPlot(sent, pl);
      }
    } on ApiException catch (e) {
      lastSyncError.value = e.userMessage;
    }
  }

  /// Envoie la modification (fiche déjà connue de l'API).
  Future<void> _pushUpdate(
      Producer p, String first, String last, String? phone) async {
    final id = p.remoteId;
    if (id == null)
      return; // pas encore envoyée : l'envoi initial portera les valeurs à jour
    try {
      await Get.find<ApiClient>().patch('/producers/$id', body: {
        'firstName': first,
        if (last.isNotEmpty) 'lastName': last,
        'village': p.village,
        if (ProducerRepository.apiPhone(phone) != null)
          'phone': ProducerRepository.apiPhone(phone),
      });
      pending.removeWhere((x) => x.label == 'Modification · ${p.name}');
    } on ApiException catch (e) {
      lastSyncError.value = e.userMessage;
    }
  }

  /// Dernière erreur d'envoi à l'API (null si tout est parti).
  final lastSyncError = RxnString();

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
        pl.statusInk,
        remoteId: pl.remoteId, areaHa: pl.areaHa, lat: pl.lat, lng: pl.lng);
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
    _pushPlot(owner, plot);
  }

  /// Envoie la parcelle : un nom, la surface en hectares et le point central.
  /// Le contour complet reste sur le téléphone (l'API ne garde qu'un point).
  /// Sans fiche déjà envoyée, ou hors ligne, la parcelle reste en attente.
  Future<void> _pushPlot(Producer owner, Plot plot) async {
    final pid = owner.remoteId;
    if (pid == null || plot.remoteId != null) return;
    try {
      final data =
          await Get.find<ApiClient>().post('/producers/$pid/plots', body: {
        'name': 'Parcelle ${plot.code}',
        'areaHa': double.parse(plot.areaHa.toStringAsFixed(4)),
        if (owner.village.isNotEmpty) 'village': owner.village,
        if (plot.lat != null) 'lat': plot.lat,
        if (plot.lng != null) 'lng': plot.lng,
      }) as Map<String, dynamic>;
      final list = plots[owner.code] ?? const <Plot>[];
      final i = list.indexWhere((x) => x.code == plot.code);
      if (i >= 0) {
        plots[owner.code] = [...list]..[i] =
            list[i].withRemoteId(data['id'].toString());
      }
      pending.removeWhere((x) => x.label == 'Parcelle relevée · ${plot.code}');
      await _pushCrops(
          owner, plot.code); // cultures déclarées avant l'envoi de la parcelle
    } on ApiException catch (e) {
      lastSyncError.value = e.userMessage;
    }
  }

  /// Enregistre les cultures de la parcelle (une liste par saison, les vides sont ignorées).
  void declareCrops(
      Producer owner, String plotCode, Map<int, List<Crop>> perSeason) {
    final before = [
      for (final l in cropPlans[plotCode]?.values ?? const <List<Crop>>[]) ...l
    ];
    cropPlans[plotCode] = {
      for (final e in perSeason.entries)
        if (e.value.isNotEmpty) e.key: [for (final c in e.value) c.copy()],
    };
    cropsToday.value++;
    final label = 'Cultures · $plotCode';
    if (!pending.any((x) => x.label == label))
      pending.add(PendingItem(Symbols.potted_plant_rounded, label));
    _pushCrops(owner, plotCode, removed: before);
  }

  static const _seasonLabels = ['Horticole 2026', 'Contre-saison 2026'];

  /// Synchronise les cultures d'une parcelle : crée les nouvelles, met à jour les
  /// existantes, supprime les retirées. La part en % reste locale (pas de champ côté API).
  Future<void> _pushCrops(Producer owner, String plotCode,
      {List<Crop> removed = const []}) async {
    final pid = owner.remoteId;
    final plot = plots[owner.code]?.firstWhereOrNull((x) => x.code == plotCode);
    final plotId = plot?.remoteId;
    if (pid == null || plotId == null)
      return; // en attente de l'envoi de la fiche / parcelle
    final api = Get.find<ApiClient>();
    final keep = {
      for (final l in cropPlans[plotCode]?.values ?? const <List<Crop>>[])
        for (final c in l) c.remoteId
    };
    try {
      for (final c in removed) {
        if (c.remoteId != null && !keep.contains(c.remoteId)) {
          await api.request('DELETE', '/producers/$pid/crops/${c.remoteId}');
        }
      }
      final plan = cropPlans[plotCode] ?? const <int, List<Crop>>{};
      for (final e in plan.entries) {
        for (final c in e.value) {
          final body = {
            'name': c.name,
            if (c.variety.isNotEmpty) 'variety': c.variety,
            'season': _seasonLabels[e.key],
          };
          if (c.remoteId == null) {
            final data = await api.post('/producers/$pid/crops',
                body: {...body, 'plotId': plotId}) as Map<String, dynamic>;
            c.remoteId = data['id'].toString();
          } else {
            await api.patch('/producers/$pid/crops/${c.remoteId}', body: body);
          }
        }
      }
      pending.removeWhere((x) => x.label == 'Cultures · $plotCode');
    } on ApiException catch (e) {
      lastSyncError.value = e.userMessage;
    }
  }

  void resolveIssue(SyncIssue issue) {
    toFix.remove(issue);
    pending.add(PendingItem(issue.icon, 'Correction · ${issue.owner}'));
  }

  void markSent() => pending.clear();
}
