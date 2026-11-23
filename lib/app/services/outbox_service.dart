import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data/local/app_database.dart';
import 'api_client.dart';
import 'network_service.dart';
import 'producers_service.dart';

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

  /// Envoie les entrées en attente. Renvoie le nombre envoyées avec succès.
  Future<int> flush() async {
    if (flushing.value) return 0;
    // Simulation hors ligne (Profil › Réseau) : on ne tente pas le serveur.
    if (Get.isRegistered<NetworkService>() &&
        !Get.find<NetworkService>().online.value) {
      return 0;
    }
    flushing.value = true;
    lastError.value = null;
    var ok = 0;
    try {
      final pending = await _db.pendingOutbox();
      for (final entry in pending) {
        try {
          await _dispatch(entry);
          await _db.markOutbox(entry.id, status: 'sent');
          ok++;
        } catch (e) {
          debugPrint('[ERROR][OutboxService.flush] $e');
          await _db.markOutbox(entry.id, status: 'error', error: e.toString());
          lastError.value = e.toString();
        }
      }
    } finally {
      flushing.value = false;
    }
    return ok;
  }

  Future<void> _dispatch(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    if (entry.entity == 'producer' && entry.operation == 'create') {
      final svc = Get.find<ProducersService>();
      await svc.create(
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
      return;
    }
    // Autres entités : POST générique si path fourni.
    final path = payload['path'] as String?;
    if (path != null) {
      await _client.post(path, body: payload['body'] ?? payload);
      return;
    }
    throw StateError('Mutation non supportée : ${entry.entity}/${entry.operation}');
  }
}
