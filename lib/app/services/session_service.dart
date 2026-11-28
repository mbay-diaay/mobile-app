import 'dart:async';

import 'package:drift/drift.dart' as drift;
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
import 'outbox_service.dart';
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

  /// Epoch ms jusqu’à laquelle le PIN reste bloqué (persisté).
  final lockedUntilMs = 0.obs;

  /// True si le téléphone est activé mais le PIN est illisible (échec fermé).
  final pinMissing = false.obs;

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
  static const _kFailedAttempts = 'pin_failed_attempts';
  static const _kLockedUntil = 'pin_locked_until';
  static const _kProdId = 'producer_user_id';
  static const _kProdName = 'producer_user_name';
  static const _kProdEmail = 'producer_user_email';
  static const _kProdScoop = 'producer_user_scoop';
  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = appSecureStorage;

  /// Profil producteur persisté (cold start sans `Get.arguments`).
  final producerUser = Rxn<AuthUser>();

  /// Relit l'activation enregistrée ; le PIN est dans le trousseau, jamais en clair.
  Future<SessionService> init() async {
    _prefs = await SharedPreferences.getInstance();
    activated.value = _prefs.getBool(_kActivated) ?? false;
    appRole.value = _parseAppRole(_prefs.getString(_kAppRole));
    failedAttempts.value = _prefs.getInt(_kFailedAttempts) ?? 0;
    lockedUntilMs.value = _prefs.getInt(_kLockedUntil) ?? 0;
    _expireLockIfNeeded();
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
    final prodId = _prefs.getString(_kProdId);
    if (prodId != null && prodId.isNotEmpty) {
      producerUser.value = AuthUser(
        id: prodId,
        email: _prefs.getString(_kProdEmail) ?? '',
        name: _prefs.getString(_kProdName) ?? 'Producteur',
        role: AuthUser.producerRole,
        scoopName: _prefs.getString(_kProdScoop),
      );
    }
    final loaded = await _loadPin();
    if (loaded == null) {
      pinMissing.value = true;
      pin.value = '';
    } else {
      pinMissing.value = false;
      pin.value = loaded;
    }
    ever(pin, (p) {
      if (p.isEmpty) return;
      unawaited(_secure.write(key: _kPin, value: p));
    });
    return this;
  }

  void _expireLockIfNeeded() {
    final until = lockedUntilMs.value;
    if (until <= 0) return;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      lockedUntilMs.value = 0;
      failedAttempts.value = 0;
      unawaited(_prefs.remove(_kLockedUntil));
      unawaited(_prefs.setInt(_kFailedAttempts, 0));
    }
  }

  /// Secondes restantes avant nouvel essai PIN (0 = libre).
  int get lockRemainingSeconds {
    _expireLockIfNeeded();
    final until = lockedUntilMs.value;
    if (until <= 0) return 0;
    final ms = until - DateTime.now().millisecondsSinceEpoch;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> clearPinLock() async {
    failedAttempts.value = 0;
    lockedUntilMs.value = 0;
    await _prefs.setInt(_kFailedAttempts, 0);
    await _prefs.remove(_kLockedUntil);
  }

  /// Mémorise le producteur connecté (API ou vault local) pour le prochain boot.
  Future<void> saveProducerUser(AuthUser user) async {
    producerUser.value = user;
    await _prefs.setString(_kProdId, user.id);
    await _prefs.setString(_kProdName, user.name);
    await _prefs.setString(_kProdEmail, user.email);
    if (user.scoopName != null) {
      await _prefs.setString(_kProdScoop, user.scoopName!);
    } else {
      await _prefs.remove(_kProdScoop);
    }
  }

  Future<void> clearProducerUser() async {
    producerUser.value = null;
    await _prefs.remove(_kProdId);
    await _prefs.remove(_kProdName);
    await _prefs.remove(_kProdEmail);
    await _prefs.remove(_kProdScoop);
  }

  /// Migre un ancien PIN SharedPreferences vers le trousseau, puis le supprime.
  /// Renvoie null si le téléphone est activé mais aucun PIN n’est lisible (échec fermé).
  Future<String?> _loadPin() async {
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
    // Activé sans PIN lisible → ne pas retomber sur 1234.
    if (activated.value) return null;
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
    await clearProducerUser();
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
    pinMissing.value = false;
    pin.value = defaultPin;
    permissions.clear();
    usingDemoCatalog.value = false;
    // Rien de l'utilisateur précédent ne doit rester affiché.
    producers.clear();
    recent.clear();
    plots.clear();
    cropPlans.clear();
    todoCount.value = 0;
    await clearPinLock();
    await _prefs.remove(_kActivated);
    await _prefs.remove(_kAppRole);
    appRole.value = null;
    await clearProducerUser();
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

  /// True seulement après [loadDemoCatalog] (seed local) — faux pour un boot API.
  final usingDemoCatalog = false.obs;

  /// Catalogue de démonstration (seed local Fatou Sarr) — pas au cold start API.
  void loadDemoCatalog() {
    usingDemoCatalog.value = true;
    producers.assignAll(MockData.producers);
    recent.assignAll(MockData.recent);
    toFix.assignAll(MockData.syncIssues);
    pending.assignAll(MockData.pending);
    todoCount.value = 8;
    createdToday.value = 4;
    surveyedToday.value = 1;
    cropsToday.value = 0;
  }

  /// Recalcule « À compléter » hors seed : fiches nouvelles + parcelles sans cultures.
  void refreshTodoCount() {
    if (usingDemoCatalog.value) return;
    var n = 0;
    for (final p in activeProducers) {
      if (p.isNew) n++;
      final pls = plotsOf(p);
      if (pls.isEmpty) {
        n++;
      } else {
        for (final pl in pls) {
          final plan = cropPlans[pl.code];
          if (plan == null || plan.values.every((l) => l.isEmpty)) n++;
        }
      }
    }
    todoCount.value = n;
  }

  /// Todos dérivés de la session (hors seed MockData).
  List<TodoItem> buildTodos() {
    if (usingDemoCatalog.value) return MockData.todos;
    final out = <TodoItem>[];
    for (final p in activeProducers) {
      if (p.isNew) {
        out.add(TodoItem(
          Symbols.person_rounded,
          AppColors.amberSoft,
          AppColors.amberInk,
          'Compléter la fiche',
          p.name,
        ));
      }
      final pls = plotsOf(p);
      if (pls.isEmpty) {
        out.add(TodoItem(
          Symbols.pentagon_rounded,
          AppColors.blueSoft,
          AppColors.blueInk,
          'Relever une parcelle',
          p.name,
          isPlot: true,
        ));
      }
      for (final pl in pls) {
        final plan = cropPlans[pl.code];
        if (plan == null || plan.values.every((l) => l.isEmpty)) {
          out.add(TodoItem(
            Symbols.eco_rounded,
            AppColors.sage,
            AppColors.forest,
            'Déclarer les cultures · ${pl.code}',
            '${pl.code} · ${p.name}',
            isPlot: true,
          ));
        }
      }
    }
    return out;
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
    await hydrateLocalProducers();
  }

  /// Réinjecte les fiches Drift (`LocalProducers`) absentes de la mémoire.
  Future<void> hydrateLocalProducers() async {
    if (!Get.isRegistered<AppDatabase>()) return;
    try {
      final rows = await Get.find<AppDatabase>().allProducers();
      for (final row in rows) {
        final idx = producers.indexWhere((p) =>
            p.code == row.code ||
            (row.remoteId != null &&
                row.remoteId!.isNotEmpty &&
                p.remoteId == row.remoteId));
        if (idx >= 0) {
          final cur = producers[idx];
          if (row.remoteId != null &&
              row.remoteId!.isNotEmpty &&
              cur.remoteId != row.remoteId) {
            _replace(cur, cur.copyWith(remoteId: row.remoteId, isNew: false));
          }
          continue;
        }
        final name = '${row.firstName} ${row.lastName}'.trim();
        final initials = name.isEmpty
            ? '?'
            : (name.split(RegExp(r'\s+')).length >= 2
                ? '${name[0]}${name.split(RegExp(r'\s+')).last[0]}'
                : name[0]);
        producers.insert(
          0,
          Producer(
            initials: initials.toUpperCase(),
            name: name.isEmpty ? row.code : name,
            village: row.village,
            age: row.age,
            tint: MockData.tints[producers.length % MockData.tints.length],
            code: row.code,
            phone: row.phone.isEmpty ? '—' : row.phone,
            sex: row.sex.isEmpty ? '—' : row.sex,
            org: row.org.isEmpty ? '—' : row.org,
            isNew: row.isNew,
            remoteId: row.remoteId,
            archived: row.archived,
            createdAt: row.updatedAt,
          ),
        );
      }
      if (rows.isNotEmpty) {
        recent.assignAll(producers.where((p) => !p.archived).take(3));
        refreshTodoCount();
      }
    } catch (e) {
      debugPrint('[ERROR][SessionService.hydrateLocalProducers] $e');
    }
  }

  /// Persiste une fiche dans Drift pour survivre au cold start.
  Future<void> persistLocalProducer(Producer p,
      {required String first, required String last}) async {
    if (!Get.isRegistered<AppDatabase>()) return;
    try {
      await Get.find<AppDatabase>().upsertProducer(LocalProducersCompanion(
        clientId: drift.Value(p.code),
        remoteId: drift.Value(p.remoteId),
        code: drift.Value(p.code),
        firstName: drift.Value(first),
        lastName: drift.Value(last),
        village: drift.Value(p.village),
        phone: drift.Value(p.phone),
        sex: drift.Value(p.sex),
        org: drift.Value(p.org),
        age: drift.Value(p.age),
        isNew: drift.Value(p.isNew),
        archived: drift.Value(p.archived),
        updatedAt: drift.Value(DateTime.now()),
      ));
    } catch (e) {
      debugPrint('[ERROR][SessionService.persistLocalProducer] $e');
    }
  }

  /// Après flush outbox create : rattache `remoteId` / `code` serveur.
  void reconcileProducerCreate({
    required Map<String, dynamic> payload,
    required String remoteId,
    String? code,
  }) {
    final first = (payload['firstName'] ?? payload['first'] ?? '').toString();
    final last = (payload['lastName'] ?? payload['last'] ?? '').toString();
    final phone = (payload['phone'] ?? '').toString();
    final name = '$first $last'.trim();
    final match = producers.firstWhereOrNull((p) {
      if (p.remoteId == remoteId) return true;
      if (code != null && code.isNotEmpty && p.code == code) return true;
      final sameName = name.isNotEmpty && p.name == name;
      final samePhone = phone.isNotEmpty &&
          p.phone.replaceAll(RegExp(r'\D'), '').endsWith(
              phone.replaceAll(RegExp(r'\D'), ''));
      return sameName && (phone.isEmpty || samePhone) && p.isNew;
    });
    if (match == null) return;
    final sent = match.copyWith(
      remoteId: remoteId,
      code: (code != null && code.isNotEmpty) ? code : match.code,
      isNew: false,
    );
    _replace(match, sent);
    unawaited(persistLocalProducer(sent, first: first, last: last));
    pending.removeWhere((x) =>
        x.label.endsWith('· ${match.name}') &&
        x.label.startsWith('Nouvelle fiche'));
    refreshTodoCount();
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
    usingDemoCatalog.value = false;
    final local = producers.where((p) => p.isNew).toList();
    if (server.isEmpty) {
      if (local.isEmpty) {
        producers.clear();
        recent.clear();
        refreshTodoCount();
        return;
      }
      producers.assignAll(local);
      recent.assignAll(local.take(3));
      refreshTodoCount();
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
    refreshTodoCount();
  }

  bool checkPin(String value) {
    _expireLockIfNeeded();
    if (pinMissing.value || pin.value.isEmpty) return false;
    if (lockRemainingSeconds > 0) return false;
    if (value == pin.value) {
      unawaited(clearPinLock());
      return true;
    }
    failedAttempts.value++;
    unawaited(_prefs.setInt(_kFailedAttempts, failedAttempts.value));
    if (failedAttempts.value >= maxAttempts) {
      lockedUntilMs.value =
          DateTime.now().add(const Duration(minutes: 3)).millisecondsSinceEpoch;
      unawaited(_prefs.setInt(_kLockedUntil, lockedUntilMs.value));
    }
    return false;
  }

  /// Vérifie le PIN sans compter d’échec (changement de PIN depuis le profil).
  bool matchesPin(String value) =>
      !pinMissing.value && pin.value.isNotEmpty && value == pin.value;

  bool get locked =>
      lockRemainingSeconds > 0 || failedAttempts.value >= maxAttempts;

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
    unawaited(persistLocalProducer(p, first: first, last: last));
    // Déjà créée sur le serveur / outbox par l'écran : rien à renvoyer.
    if (!synced) {
      pending.add(PendingItem(
          Symbols.person_add_rounded, 'Nouvelle fiche · ${p.name}'));
      if (queueRemote) unawaited(_pushCreate(p, first, last));
    }
    if (cniPhotos && !synced)
      pending.add(
          PendingItem(Symbols.badge_rounded, 'CNI recto + verso · ${p.name}'));
    refreshTodoCount();
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

  /// Tente `POST /producers` (absent sur OpenAPI prod) ; sinon file outbox locale.
  Future<void> _pushCreate(Producer p, String first, String last) async {
    final payload = <String, dynamic>{
      'firstName': first,
      'lastName': last.isEmpty ? first : last,
      if (ProducerRepository.apiPhone(p.phone == '—' ? null : p.phone) != null)
        'phone': ProducerRepository.apiPhone(p.phone),
      if (p.village.isNotEmpty) 'village': p.village,
      'status': 'recensé',
    };
    try {
      final data = await Get.find<ApiClient>().post('/producers', body: payload)
          as Map<String, dynamic>;
      final sent = p.copyWith(
          code: (data['code'] ?? p.code).toString(),
          remoteId: data['id']?.toString(),
          isNew: false);
      _replace(p, sent);
      await persistLocalProducer(sent, first: first, last: last);
      pending.removeWhere((x) =>
          x.label.endsWith('· ${p.name}') &&
          (x.label.startsWith('Nouvelle fiche')));
      if (sent.code != p.code && plots.containsKey(p.code)) {
        plots[sent.code] = plots.remove(p.code)!;
      }
      for (final pl in List<Plot>.of(plots[sent.code] ?? const <Plot>[])) {
        await _pushPlot(sent, pl);
      }
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService._pushCreate] $e');
      // Route absente (prod) ou réseau : garder en attente + outbox.
      lastSyncError.value = e.code == 'NOT_FOUND'
          ? 'Création producteur pas encore disponible sur le serveur — fiche gardée en local.'
          : e.userMessage;
      if (Get.isRegistered<OutboxService>()) {
        unawaited(Get.find<OutboxService>().enqueueProducerCreate({
          ...payload,
          'clientCode': p.code,
        }));
      }
    }
  }

  /// Envoie la modification (fiche déjà connue de l'API) via `PATCH /producers/{id}`.
  Future<void> _pushUpdate(
      Producer p, String first, String last, String? phone) async {
    final id = p.remoteId;
    if (id == null) return;
    try {
      final sexApi = switch (p.sex) {
        'Femme' => 'F',
        'Homme' => 'H',
        _ => null,
      };
      await Get.find<ApiClient>().patch('/producers/$id', body: {
        'firstName': first,
        if (last.isNotEmpty) 'lastName': last,
        'village': p.village,
        if (ProducerRepository.apiPhone(phone) != null)
          'phone': ProducerRepository.apiPhone(phone),
        if (p.age > 0) 'age': p.age,
        if (sexApi != null) 'sex': sexApi,
      });
      pending.removeWhere((x) => x.label == 'Modification · ${p.name}');
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService._pushUpdate] $e');
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

  /// Lit les parcelles via `GET /plots?producerId=` (OpenAPI prod) et hydrate
  /// les cultures depuis `PlotDto.crops`. Lève une [ApiException] en cas d'échec.
  Future<void> loadPlots(Producer p) async {
    final id = p.remoteId;
    if (id == null) return; // fiche pas encore créée sur le serveur
    final api = Get.find<ApiClient>();
    final data = await api.get('/plots', query: {
      'producerId': id,
      'limit': 500,
      'page': 1,
    }) as Map<String, dynamic>;
    final items = data['items'] as List? ?? const [];
    final list = <Plot>[];
    for (final j in items) {
      final m = j as Map<String, dynamic>;
      final plot = _plotFromApi(m);
      _hydrateCropsFromPlot(m, plot.code);
      list.add(_withCrops(plot));
    }
    plots[p.code] = list;
    refreshTodoCount();
  }

  Plot _plotFromApi(Map<String, dynamic> m) {
    final plotId = (m['id'] ?? m['code'] ?? '').toString();
    final code = (m['code'] ?? plotId).toString();
    final ha = (m['areaHa'] as num?)?.toDouble() ??
        (m['declaredAreaHa'] as num?)?.toDouble() ??
        0;
    final centroid = m['centroid'];
    double? lat;
    double? lng;
    if (centroid is Map) {
      lat = (centroid['lat'] as num?)?.toDouble();
      lng = (centroid['lng'] as num?)?.toDouble();
    }
    lat ??= (m['lat'] as num?)?.toDouble();
    lng ??= (m['lng'] as num?)?.toDouble();
    final statusRaw = (m['status'] ?? '').toString();
    final validated = statusRaw == 'validée' || statusRaw.isEmpty;
    final landmark = (m['landmark'] ?? m['village'] ?? '').toString();
    return Plot(
      code,
      '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha',
      'Cultures à déclarer',
      validated ? 'Enregistrée' : 'À reprendre',
      validated ? AppColors.lime : AppColors.amberSoft,
      validated ? AppColors.forest : AppColors.amberInk,
      remoteId: plotId,
      areaHa: ha,
      lat: lat,
      lng: lng,
      label: landmark.isEmpty ? code : landmark,
    );
  }

  /// Cultures `PlotCropDto` → plans locaux (saison 0 = chn, 1 = cs).
  void _hydrateCropsFromPlot(Map<String, dynamic> m, String plotCode) {
    final apiCrops = m['crops'] as List? ?? const [];
    if (apiCrops.isEmpty) {
      cropPlans.remove(plotCode);
      return;
    }
    final plan = <int, List<Crop>>{};
    var i = 0;
    for (final raw in apiCrops) {
      final c = raw as Map<String, dynamic>;
      final name =
          (c['crop'] ?? c['cropRaw'] ?? c['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final share = (c['sharePct'] as num?)?.round() ?? 0;
      final seasons = c['seasons'];
      final seasonIndexes = <int>[];
      if (seasons is Map) {
        if (seasons['chn'] != null) seasonIndexes.add(0);
        if (seasons['cs'] != null) seasonIndexes.add(1);
      }
      if (seasonIndexes.isEmpty) seasonIndexes.add(0);
      final crop = _cropFromApi(c, share > 0 ? share : 0, i++);
      for (final s in seasonIndexes) {
        (plan[s] ??= []).add(crop.copy()..remoteId = crop.remoteId);
      }
    }
    // Parts manquantes : répartir également dans chaque saison non vide.
    for (final e in plan.entries) {
      final sum = e.value.fold<int>(0, (a, c) => a + c.share);
      if (sum == 0 && e.value.isNotEmpty) {
        final each = (100 / e.value.length).floor();
        for (var k = 0; k < e.value.length; k++) {
          e.value[k].share =
              k == 0 ? 100 - each * (e.value.length - 1) : each;
        }
      }
    }
    if (plan.isEmpty) {
      cropPlans.remove(plotCode);
    } else {
      cropPlans[plotCode] = plan;
    }
  }

  Crop _cropFromApi(Map<String, dynamic> c, int share, int index) {
    final name =
        (c['crop'] ?? c['cropRaw'] ?? c['name'] ?? '').toString();
    final spec = CropCatalog.byName(name) ?? CropCatalog.custom(name, index);
    return spec.toCrop(share, (c['variety'] ?? '').toString())
      ..remoteId = c['id']?.toString();
  }

  /// Tente l’envoi parcelle (route write absente en prod). Renvoie l’id serveur ou null.
  /// Sur `NOT_FOUND`, enqueue outbox et ne lève pas — la parcelle reste locale.
  Future<String?> sendPlot(Producer owner, Plot plot) async {
    final pid = owner.remoteId;
    if (pid == null) return null;
    final body = {
      'name': 'Parcelle ${plot.code}',
      'areaHa': double.parse(plot.areaHa.toStringAsFixed(4)),
      if (owner.village.isNotEmpty) 'village': owner.village,
      if (plot.lat != null) 'lat': plot.lat,
      if (plot.lng != null) 'lng': plot.lng,
    };
    try {
      final data = await Get.find<ApiClient>()
          .post('/producers/$pid/plots', body: body) as Map<String, dynamic>;
      return data['id']?.toString();
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService.sendPlot] $e');
      lastSyncError.value = e.code == 'NOT_FOUND'
          ? 'Envoi parcelle pas encore disponible sur le serveur — gardée en local.'
          : e.userMessage;
      if (Get.isRegistered<OutboxService>()) {
        await Get.find<OutboxService>().enqueueGeneric(
          entity: 'plot',
          operation: 'create',
          payload: {'path': '/producers/$pid/plots', 'body': body},
        );
      }
      if (e.code != 'NOT_FOUND' && e.code != 'NETWORK') rethrow;
      return null;
    }
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

  /// Envoie la parcelle si une route write existe ; sinon outbox (voir [sendPlot]).
  Future<void> _pushPlot(Producer owner, Plot plot) async {
    if (owner.remoteId == null || plot.remoteId != null) return;
    final id = await sendPlot(owner, plot);
    if (id == null) return;
    final list = plots[owner.code] ?? const <Plot>[];
    final i = list.indexWhere((x) => x.code == plot.code);
    if (i >= 0) {
      plots[owner.code] = [...list]..[i] = list[i].withRemoteId(id);
    }
    pending.removeWhere((x) => x.label == 'Parcelle relevée · ${plot.code}');
    try {
      await _pushCrops(owner, plot.code);
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService._pushPlot.crops] $e');
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

  /// Tente sync cultures (routes write absentes en prod). Sur NOT_FOUND → outbox.
  Future<void> _pushCrops(Producer owner, String plotCode,
      {List<Crop> removed = const []}) async {
    final pid = owner.remoteId;
    final plot = plots[owner.code]?.firstWhereOrNull((x) => x.code == plotCode);
    final plotId = plot?.remoteId;
    if (pid == null || plotId == null) return;
    final api = Get.find<ApiClient>();
    try {
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
            'sharePct': c.share,
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
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService._pushCrops] $e');
      lastSyncError.value = e.code == 'NOT_FOUND'
          ? 'Envoi cultures pas encore disponible sur le serveur — gardées en local.'
          : e.userMessage;
      if (Get.isRegistered<OutboxService>() &&
          (e.code == 'NOT_FOUND' || e.code == 'NETWORK')) {
        final plan = cropPlans[plotCode] ?? const <int, List<Crop>>{};
        await Get.find<OutboxService>().enqueueGeneric(
          entity: 'crops',
          operation: 'sync',
          payload: {
            'path': '/producers/$pid/crops',
            'body': {
              'plotId': plotId,
              'crops': [
                for (final e in plan.entries)
                  for (final c in e.value)
                    {
                      'name': c.name,
                      'variety': c.variety,
                      'season': _seasonLabels[e.key],
                      'sharePct': c.share,
                    },
              ],
            },
          },
        );
      } else if (e.code != 'NOT_FOUND' && e.code != 'NETWORK') {
        rethrow;
      }
    }
  }

  void resolveIssue(SyncIssue issue) {
    toFix.remove(issue);
    pending.add(PendingItem(issue.icon, 'Correction · ${issue.owner}'));
  }

  /// Retire au plus [flushed] éléments de la file UI (pas un clear aveugle).
  void markSent({int flushed = 0}) {
    if (flushed <= 0) return;
    final n = flushed.clamp(0, pending.length);
    pending.removeRange(0, n);
  }

  /// True s’il reste des mutations Drift non envoyées.
  Future<bool> hasPendingOutbox() async {
    if (!Get.isRegistered<AppDatabase>()) return false;
    try {
      final rows = await Get.find<AppDatabase>().pendingOutbox();
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[ERROR][SessionService.hasPendingOutbox] $e');
      return false;
    }
  }

  /// Demande de correction (`POST /producers/{id}/corrections`).
  Future<void> submitCorrection({
    required Producer producer,
    required String field,
    required String from,
    required String to,
    required String motif,
  }) async {
    final id = producer.remoteId;
    if (id == null || id.isEmpty) {
      queueCommerce(
        Symbols.edit_note_rounded,
        'Correction · ${producer.name} · $field',
      );
      return;
    }
    try {
      await Get.find<ApiClient>().post('/producers/$id/corrections', body: {
        'changes': [
          {'field': field, 'from': from, 'to': to},
        ],
        'motif': motif,
      });
    } on ApiException catch (e) {
      debugPrint('[ERROR][SessionService.submitCorrection] $e');
      lastSyncError.value = e.userMessage;
      queueCommerce(
        Symbols.edit_note_rounded,
        'Correction · ${producer.name} · $field',
      );
      rethrow;
    }
  }
}
