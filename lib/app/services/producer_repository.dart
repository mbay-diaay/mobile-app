import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_data.dart';
import 'api_client.dart';
import "package:flutter/foundation.dart";

/// Annuaire des producteurs : lu depuis `GET /producers`, gardé en cache local pour
/// rester consultable hors ligne. L'API n'expose que le code, le nom, la SCOOP, le statut
/// et la CNI masquée : le reste de la fiche (village, âge…) garde des valeurs par défaut.
class ProducerRepository extends GetxService {
  static const _kCache = 'producers_cache';

  final loading = false.obs;
  final lastError = Rxn<ApiException>();

  /// Dernière lecture réussie (null si l'annuaire vient du cache ou n'est pas chargé).
  final syncedAt = Rxn<DateTime>();

  /// Fiches du cache local (lecture instantanée au démarrage).
  Future<List<Producer>> cached() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kCache);
      if (raw == null) return const [];
      return [
        for (final j in jsonDecode(raw) as List)
          _fromJson(j as Map<String, dynamic>)
      ];
    } catch (e) {
      debugPrint("[ERROR][ProducerRepository.cached] ${e}");
      return const [];
    }
  }

  /// Récupère l'annuaire (toutes les pages) et met le cache à jour.
  /// Hors ligne ou en erreur : lève l'exception, le cache reste intact.
  Future<List<Producer>> fetch() async {
    final client = Get.find<ApiClient>();
    loading.value = true;
    lastError.value = null;
    try {
      final items = <Map<String, dynamic>>[];
      String? cursor;
      do {
        final data = await client.get('/producers',
                query: {if (cursor != null) 'cursor': cursor})
            as Map<String, dynamic>;
        items.addAll(
            [for (final j in data['items'] as List) j as Map<String, dynamic>]);
        cursor = data['nextCursor'] as String?;
      } while (cursor != null);
      await _loadScoops(client);
      final list = [for (final j in items) _fromJson(j)];
      (await SharedPreferences.getInstance())
          .setString(_kCache, jsonEncode(items));
      syncedAt.value = DateTime.now();
      return list;
    } on ApiException catch (e) {
      debugPrint("[ERROR][ProducerRepository.fetch] ${e}");
      lastError.value = e;
      rethrow;
    } finally {
      loading.value = false;
    }
  }

  /// Noms des SCOOP (id → nom), pour afficher « SCOOP Démo Niayes » plutôt qu'un identifiant.
  final _scoops = <String, String>{};

  Future<void> _loadScoops(ApiClient client) async {
    try {
      final data = await client.get('/scoops') as Map<String, dynamic>;
      for (final j in data['items'] as List) {
        _scoops[j['id'].toString()] = j['name'].toString();
      }
    } catch (e) {
      debugPrint("[ERROR][ProducerRepository._loadScoops] ${e}");
    }
  }

  Future<void> clearCache() async {
    syncedAt.value = null;
    (await SharedPreferences.getInstance()).remove(_kCache);
  }

  Producer _fromJson(Map<String, dynamic> j) {
    final first = (j['firstName'] ?? '').toString().trim();
    final last = (j['lastName'] ?? '').toString().trim();
    final code = (j['code'] ?? j['id'] ?? '').toString();
    final initials =
        '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
            .toUpperCase();
    final phone = (j['phone'] ?? '').toString();
    final scoop = _scoops[j['scoopId'].toString()];
    return Producer(
      initials: initials.isEmpty ? '?' : initials,
      name: '$first $last'.trim(),
      village: (j['village'] ?? '').toString().isEmpty
          ? (scoop ?? '')
          : j['village'].toString(),
      age: 0,
      tint: MockData.tints[code.hashCode.abs() % MockData.tints.length],
      code: code,
      phone: phone.isEmpty ? '—' : formatPhone(phone),
      sex: '—',
      org: scoop ?? (j['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      remoteId: j['id']?.toString(),
    );
  }

  /// « +221771110001 » → « +221 77 111 00 01 ».
  static String formatPhone(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('221')) {
      final n = d.substring(3);
      return '+221 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5, 7)} ${n.substring(7)}';
    }
    return raw;
  }

  /// « +221 77 111 00 01 » → « +221771110001 » (format attendu par l'API).
  static String? apiPhone(String? local) {
    if (local == null) return null;
    final d = local.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    return d.length == 9 ? '+221$d' : '+$d';
  }
}
