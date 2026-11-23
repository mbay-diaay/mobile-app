import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../data/crop_catalog.dart';
import '../data/mock_data.dart';
import '../data/local/app_database.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'producer_repository.dart';
import 'secure_storage.dart';

/// Profil choisi à l’ouverture de l’app (une seule appli, deux parcours).
enum AppRole { technician, producer }

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

  /// Rôle d’entrée : technicien ou producteur (null = écran de choix).
  final appRole = Rxn<AppRole>();

  static const _kActivated = 'activated';
  static const _kAppRole = 'app_role';
  static const _kEmail = 'account_email';
  static const _kName = 'account_name';
  static const _kScoop = 'account_scoop';
  static const _kPin = 'pin';
  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = appSecureStorage;

  /// Relit l'activation enregistrée ; le PIN est dans le trousseau, jamais en clair.
  Future<SessionService> init() async {
    _prefs = await SharedPreferences.getInstance();
    activated.value = _prefs.getBool(_kActivated) ?? false;
    appRole.value = _parseAppRole(_prefs.getString(_kAppRole));
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
    pin.value = await _loadPin();
    ever(pin, (p) {
      unawaited(_secure.write(key: _kPin, value: p));
    });
    return this;
  }

  /// Migre un ancien PIN SharedPreferences vers le trousseau, puis le supprime.
  Future<String> _loadPin() async {
    try {
      final secure = await _secure.read(key: _kPin);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (e) {
      debugPrint('[ERROR][SessionService._loadPin] $e');
    }
    final legacy = _prefs.getString(_kPin);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: _kPin, value: legacy);
      } catch (e) {
        debugPrint('[ERROR][SessionService._loadPin.migrate] $e');
      }
      await _prefs.remove(_kPin);
      return legacy;
    }
    return defaultPin;
  }

  AppRole? _parseAppRole(String? raw) => switch (raw) {
        'technician' => AppRole.technician,
        'producer' => AppRole.producer,
        _ => null,
      };

  Future<void> setAppRole(AppRole role) async {
    appRole.value = role;
    await _prefs.setString(
        _kAppRole, role == AppRole.technician ? 'technician' : 'producer');
  }

  Future<void> clearAppRole() async {
    appRole.value = null;
    await _prefs.remove(_kAppRole);
  }

  /// Fin de l'activation (écran 04).
  Future<void> completeActivation() async {
    activated.value = true;
    // Activation = parcours technicien ; verrouille le rôle pour le prochain démarrage.
    if (appRole.value != AppRole.technician) {
      await setAppRole(AppRole.technician);
    }
    await _prefs.setBool(_kActivated, true);
    await _prefs.setString(_kEmail, account.value.email);
    await _prefs.setString(_kName, account.value.fullName);
    await _prefs.setString(_kScoop, account.value.scoop);
    try {
      await _secure.write(key: _kPin, value: pin.value);
    } catch (e) {
      debugPrint('[ERROR][SessionService.completeActivation] $e');
    }
    await _prefs.remove(_kPin);
  }

  /// Révocation (écran 25) : le prochain démarrage repasse par l'activation.
  Future<void> revoke() async {
    if (Get.isRegistered<AuthService>()) {
      unawaited(Get.find<AuthService>().logout());
    }
    if (Get.isRegistered<ProducerRepository>()) {
      Get.find<ProducerRepository>().clearCache();
    }
    if (Get.isRegistered<AppDatabase>()) {
      unawaited(Get.find<AppDatabase>().clearAll());
    }
    activated.value = false;
    failedAttempts.value = 0;
    pin.value = defaultPin;
    permissions.clear();
    // Rien de l'utilisateur précédent ne doit rester affiché.
    producers.clear();
    recent.clear();
    plots.clear();
    cropPlans.clear();
    await _prefs.remove(_kActivated);
    await _prefs.remove(_kAppRole);
    appRole.value = null;
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kName);
    await _prefs.remove(_kScoop);
    await _prefs.remove(_kPin);
    try {
      await _secure.delete(key: _kPin);
    } catch (e) {
      debugPrint('[ERROR][SessionService.revoke] $e');
    }
  }

  /// Annuaire : vide au boot ; rempli par l’API / cache, ou par [loadDemoCatalog] (seed local).
  final producers = <Producer>[].obs;
  final recent = <Producer>[].obs;
  final plots = <String, List<Plot>>{}.obs; // clé : code producteur

  /// Cultures déclarées par parcelle (clé : code parcelle) et par saison
  /// (0 = campagne horticole, 1 = contre-saison). Gardées en mémoire, hors ligne.
  final cropPlans = <String, Map<int, List<Crop>>>{}.obs;
  final toFix = <SyncIssue>[].obs;
  final pending = <PendingItem>[].obs;
  final todoCount = 0.obs;

  final createdToday = 0.obs;
  final surveyedToday = 0.obs;
  final cropsToday = 0.obs;

  /// Catalogue de démonstration (seed local Fatou Sarr) — pas au cold start API.
  void loadDemoCatalog() {
    producers.assignAll(MockData.producers);
    recent.assignAll(MockData.recent);
    toFix.assignAll(MockData.syncIssues);
    pending.assignAll(MockData.pending);
    todoCount.value = 8;
    createdToday.value = 4;
    surveyedToday.value = 1;
    cropsToday.value = 0;
  }

  int _nextProducer = 20;
  int _nextPlot = 35;

  /// Permissions du technicien (copie de `GET /me`), pour les gardes UI.
  final permissions = <String>[].obs;

  bool can(String permission) => permissions.contains(permission);

  void signIn(TestAccount a, {List<String> permissions = const []}) {
    account.value = a;
    this.permissions.assignAll(permissions);
  }

  /// Recharge le profil API après reconnexion (même compte, données locales gardées).
  Future<void> refreshMe() async {
    final me = await Get.find<AuthService>().me();
    signIn(
      TestAccount.fromUser(me, scoop: me.scoopName ?? ''),
      permissions: me.permissions,
    );
  }

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
      debugPrint("[ERROR][SessionService.refreshProducers] ${e}");
      return e;
    }
  }

  /// Remplace l'annuaire par celui de l'API / cache ; les fiches locales non sync
  /// restent en tête. Liste serveur vide → on ne réinjecte pas MockData.
  void applyServerProducers(List<Producer> server) {
    final local = producers.where((p) => p.isNew).toList();
    if (server.isEmpty) {
      if (local.isEmpty) return;
      producers.assignAll(local);
      recent.assignAll(local.take(3));
      return;
    }
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

  /// Vérifie le PIN sans compter d’échec (changement de PIN depuis le profil).
  bool matchesPin(String value) => value == pin.value;

  bool get locked => failedAttempts.value >= maxAttempts;

  void visit(Producer p) {
    recent.removeWhere((x) => x.code == p.code);
    recent.insert(0, p);
    if (recent.length > 3) recent.removeRange(3, recent.length);
  }

  /// [queueRemote] : false si l’écran a déjà géré API ou outbox (évite un double envoi).
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
    String? remoteId,
    bool synced = false,
    bool queueRemote = true,
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
      remoteId: remoteId,
    );
    producers.insert(0, p);
    visit(p);
    createdToday.value++;
    // Déjà créée sur le serveur / outbox par l'écran : rien à renvoyer.
    if (!synced) {
      pending.add(PendingItem(
          Symbols.person_add_rounded, 'Nouvelle fiche · ${p.name}'));
      if (queueRemote) unawaited(_pushCreate(p, first, last));
    }
    if (cniPhotos && !synced)
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
      debugPrint("[ERROR][SessionService._pushPlot] ${e}");
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
      debugPrint("[ERROR][SessionService._pushUpdate] ${e}");
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
    final base = plots[p.code] ?? const <Plot>[];
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
        remoteId: pl.remoteId,
        areaHa: pl.areaHa,
        lat: pl.lat,
        lng: pl.lng,
        label: pl.label);
  }

  /// Copie de travail des cultures d'une parcelle pour une saison.
  List<Crop> cropsOf(String plotCode, int season) => [
        for (final c in cropPlans[plotCode]?[season] ?? const <Crop>[]) c.copy()
      ];

  String nextPlotCode() => 'PA-${(_nextPlot++).toString().padLeft(4, '0')}';

  /// Lit les parcelles et cultures de la fiche sur le serveur (`GET /producers/:id`) et
  /// remplace ce qui est affiché. Lève une [ApiException] en cas d'échec.
  Future<void> loadPlots(Producer p) async {
    final id = p.remoteId;
    if (id == null) return; // fiche pas encore créée sur le serveur
    final data = await Get.find<ApiClient>().get('/producers/$id')
        as Map<String, dynamic>;
    final apiCrops = [
      for (final c in (data['crops'] as List? ?? const []))
        c as Map<String, dynamic>
    ];
    final list = <Plot>[];
    for (final j in (data['plots'] as List? ?? const [])) {
      final m = j as Map<String, dynamic>;
      final plotId = m['id'].toString();
      final ha = (m['areaHa'] as num?)?.toDouble() ?? 0;
      // Cultures de la parcelle, par saison (parts égales : le serveur n'a pas de %).
      final bySeason = <int, List<Map<String, dynamic>>>{};
      for (final c
          in apiCrops.where((c) => c['plotId']?.toString() == plotId)) {
        final season =
            (c['season'] ?? '').toString().startsWith('Contre') ? 1 : 0;
        (bySeason[season] ??= []).add(c);
      }
      final plan = <int, List<Crop>>{};
      bySeason.forEach((season, items) {
        final each = (100 / items.length).floor();
        plan[season] = [
          for (var i = 0; i < items.length; i++)
            _cropFromApi(
                items[i], i == 0 ? 100 - each * (items.length - 1) : each, i)
        ];
      });
      if (plan.isEmpty) {
        cropPlans.remove(plotId);
      } else {
        cropPlans[plotId] = plan;
      }
      final raw = (m['name'] ?? '').toString();
      list.add(_withCrops(Plot(
          plotId,
          '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha',
          'Cultures à déclarer',
          'Enregistrée',
          AppColors.lime,
          AppColors.forest,
          remoteId: plotId,
          areaHa: ha,
          lat: (m['lat'] as num?)?.toDouble(),
          lng: (m['lng'] as num?)?.toDouble(),
          label: raw.isEmpty ? plotId : raw)));
    }
    plots[p.code] = list;
  }

  Crop _cropFromApi(Map<String, dynamic> c, int share, int index) {
    final name = (c['name'] ?? '').toString();
    final spec = CropCatalog.byName(name) ?? CropCatalog.custom(name, index);
    return spec.toCrop(share, (c['variety'] ?? '').toString())
      ..remoteId = c['id']?.toString();
  }

  /// Envoie la parcelle au serveur (nom, surface en hectares, point central) et renvoie son
  /// identifiant. Lève une [ApiException] si le serveur refuse : l'écran l'affiche et
  /// propose de réessayer. Le contour complet reste sur le téléphone.
  Future<String?> sendPlot(Producer owner, Plot plot) async {
    final pid = owner.remoteId;
    if (pid == null) return null; // fiche de démonstration : rien à envoyer
    final data =
        await Get.find<ApiClient>().post('/producers/$pid/plots', body: {
      'name': 'Parcelle ${plot.code}',
      'areaHa': double.parse(plot.areaHa.toStringAsFixed(4)),
      if (owner.village.isNotEmpty) 'village': owner.village,
      if (plot.lat != null) 'lat': plot.lat,
      if (plot.lng != null) 'lng': plot.lng,
    }) as Map<String, dynamic>;
    return data['id']?.toString();
  }

  /// Ajoute la parcelle à la fiche, une fois enregistrée (ou sans envoi pour une fiche de démonstration).
  void addPlot(Producer owner, Plot plot, double area) {
    plots[owner.code] = [plot, ...plotsOf(owner)];
    surveyedToday.value++;
    if (plot.remoteId == null) {
      pending.add(PendingItem(
          Symbols.pentagon_rounded, 'Parcelle relevée · ${plot.code}'));
    }
  }

  /// MO-25 : valide ou renvoie une géométrie (nouvelle version logique côté client).
  void setPlotStatus(
    Producer owner,
    Plot plot, {
    required String status,
    required Color statusBg,
    required Color statusInk,
    String? motif,
  }) {
    final list = [...plotsOf(owner)];
    final i = list.indexWhere((x) => x.code == plot.code);
    if (i < 0) return;
    list[i] = plot.copyWith(
        status: status, statusBg: statusBg, statusInk: statusInk);
    plots[owner.code] = list;
    final label = motif == null || motif.isEmpty
        ? 'Géométrie · $status · ${plot.code}'
        : 'Géométrie · $status · ${plot.code} · $motif';
    pending.add(PendingItem(Symbols.verified_rounded, label));
  }

  /// File d'attente locale : vente ou charge (M2/M3, saisie rapide).
  void queueCommerce(IconData icon, String label) {
    pending.add(PendingItem(icon, label));
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
      debugPrint("[ERROR][SessionService._pushCrops] ${e}");
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
    _removedCrops = before;
  }

  List<Crop> _removedCrops = const [];

  /// Envoie les cultures de la parcelle enregistrées par [declareCrops]. Lève une
  /// [ApiException] en cas d'échec ; on peut rappeler (les cultures déjà créées sont conservées).
  Future<void> sendCrops(Producer owner, String plotCode) =>
      _pushCrops(owner, plotCode, removed: _removedCrops);

  static const _seasonLabels = ['Horticole 2026', 'Contre-saison 2026'];

  /// Synchronise les cultures d'une parcelle : crée les nouvelles, met à jour les
  /// existantes, supprime les retirées. La part en % reste locale (pas de champ côté API).
  Future<void> _pushCrops(Producer owner, String plotCode,
      {List<Crop> removed = const []}) async {
    final pid = owner.remoteId;
    final plot = plots[owner.code]?.firstWhereOrNull((x) => x.code == plotCode);
    final plotId = plot?.remoteId;
    if (pid == null || plotId == null)
      return; // fiche ou parcelle de démonstration
    final api = Get.find<ApiClient>();
    final keep = {
      for (final l in cropPlans[plotCode]?.values ?? const <List<Crop>>[])
        for (final c in l) c.remoteId
    };
    for (final c in removed) {
      if (c.remoteId != null && !keep.contains(c.remoteId)) {
        await api.request('DELETE', '/producers/$pid/crops/${c.remoteId}');
      }
    }
    _removedCrops = const [];
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
  }

  void resolveIssue(SyncIssue issue) {
    toFix.remove(issue);
    pending.add(PendingItem(issue.icon, 'Correction · ${issue.owner}'));
  }

  void markSent() => pending.clear();
}
