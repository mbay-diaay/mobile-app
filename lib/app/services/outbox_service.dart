import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/local/app_database.dart';
import 'api_client.dart';
import 'network_service.dart';
import 'producers_service.dart';
import 'session_service.dart';

/// Synchro réelle : file Drift → endpoints API (producteurs d’abord).
class OutboxService extends GetxService {
  OutboxService({AppDatabase? db, ApiClient? client})
      : _db = db ?? Get.find<AppDatabase>(),
        _client = client ?? Get.find<ApiClient>();

  final AppDatabase _db;
  final ApiClient _client;
  final _uuid = const Uuid();
  final flushing = false.obs;
  final lastError = RxnString();
  Worker? _netWorker;

  static const maxAttempts = 5;

  @override
  void onInit() {
    super.onInit();
    // Flush au retour réseau + au démarrage (pas seulement l’écran Sync).
    if (Get.isRegistered<NetworkService>()) {
      _netWorker = ever(Get.find<NetworkService>().online, (online) {
        if (online == true) unawaited(flush());
      });
    }
    unawaited(Future<void>.delayed(const Duration(seconds: 2), flush));
  }

  @override
  void onClose() {
    _netWorker?.dispose();
    super.onClose();
  }

  Future<String> enqueueProducerCreate(Map<String, dynamic> payload) async {
    final id = _uuid.v4();
    await _db.enqueueOutbox(
      clientMutationId: id,
      entity: 'producer',
      operation: 'create',
      payloadJson: jsonEncode(payload),
    );
    return id;
  }

  Future<String> enqueueGeneric({
    required String entity,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final id = _uuid.v4();
    await _db.enqueueOutbox(
      clientMutationId: id,
      entity: entity,
      operation: operation,
      payloadJson: jsonEncode(payload),
    );
    return id;
  }

  /// Copie une photo CNI hors du cache temporaire vers le stockage app.
  Future<String> persistCniPhoto(String tempPath, {required String side}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'cni'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = File(p.join(
        dir.path, '${DateTime.now().millisecondsSinceEpoch}_$side.jpg'));
    await File(tempPath).copy(dest.path);
    return dest.path;
  }

  /// Envoie les entrées en attente. Renvoie le nombre envoyées avec succès.
  Future<int> flush() async {
    if (flushing.value) return 0;
    if (Get.isRegistered<NetworkService>() &&
        !Get.find<NetworkService>().online.value) {
      return 0;
    }
    // Session locale producteur : pas d’API réelle.
    if (_client.isLocalSession) return 0;
    if (_client.accessToken == null) return 0;

    flushing.value = true;
    lastError.value = null;
    var ok = 0;
    try {
      final pending = await _db.pendingOutbox();
      for (final entry in pending) {
        final attempts = _attemptsOf(entry);
        if (attempts >= maxAttempts) {
          await _db.markOutbox(entry.id,
              status: 'dead', error: 'Trop de tentatives ($attempts)');
          continue;
        }
        try {
          await _dispatch(entry);
          await _db.markOutbox(entry.id, status: 'sent');
          ok++;
        } catch (e) {
          debugPrint('[ERROR][OutboxService.flush] $e');
          final msg = e.toString();
          // Routes absentes en prod : ne pas rejouer à l’infini.
          if (msg.contains('NOT_FOUND') || msg.contains('404')) {
            await _db.markOutbox(entry.id, status: 'skipped', error: msg);
          } else {
            await _db.markOutbox(
              entry.id,
              status: 'error',
              error: 'attempt=${attempts + 1}|$msg',
            );
          }
          lastError.value = msg;
        }
      }
    } finally {
      flushing.value = false;
    }
    return ok;
  }

  int _attemptsOf(OutboxEntry entry) {
    final err = entry.lastError ?? '';
    final m = RegExp(r'attempt=(\d+)').firstMatch(err);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    return entry.status == 'error' ? 1 : 0;
  }

  Future<void> _dispatch(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    if (entry.entity == 'producer' && entry.operation == 'create') {
      final svc = Get.find<ProducersService>();
      final created = await svc.create(
        firstName: payload['firstName'] as String? ??
            payload['first'] as String? ??
            '',
        lastName: payload['lastName'] as String? ??
            payload['last'] as String? ??
            '',
        village: payload['village'] as String?,
        phone: payload['phone'] as String?,
        cni: payload['cni'] as String?,
      );
      if (created == null || created['id'] == null) {
        throw StateError('Création producteur sans id serveur');
      }
      final remoteId = created['id'].toString();
      if (Get.isRegistered<SessionService>()) {
        Get.find<SessionService>().reconcileProducerCreate(
          payload: payload,
          remoteId: remoteId,
          code: created['code']?.toString() ??
              payload['clientCode']?.toString(),
        );
      }
      // Photos CNI persistées hors ligne → upload après create.
      for (final side in ['cniFrontPath', 'cniBackPath']) {
        final path = payload[side] as String?;
        if (path == null || path.isEmpty) continue;
        if (!File(path).existsSync()) continue;
        await svc.uploadPhoto(remoteId, path);
      }
      return;
    }
    if (entry.entity == 'producer_photo' && entry.operation == 'upload') {
      final producerId = payload['producerId'] as String?;
      final path = payload['path'] as String?;
      if (producerId == null || path == null) {
        throw StateError('Photo CNI incomplete');
      }
      await Get.find<ProducersService>().uploadPhoto(producerId, path);
      return;
    }
    final path = payload['path'] as String?;
    if (path != null) {
      await _client.post(path,
          body: payload['body'] as Map<String, dynamic>? ?? payload);
      return;
    }
    throw StateError(
        'Mutation non supportée : ${entry.entity}/${entry.operation}');
  }
}
