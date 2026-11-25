import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_data.dart';
import 'api_client.dart';

/// Annuaire des producteurs : `GET /producers` (pagination page/limit OpenAPI prod),
/// cache `shared_preferences` pour consultation hors ligne.
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
          fromApiJson(j as Map<String, dynamic>, scoops: _scoops)
      ];
    } catch (e) {
      debugPrint('[ERROR][ProducerRepository.cached] $e');
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
      var page = 1;
      var pages = 1;
      do {
        final data = await client.get('/producers', query: {
          'page': page,
          'limit': 100,
        }) as Map<String, dynamic>;
        final batch = data['items'] as List? ?? const [];
        items.addAll([for (final j in batch) j as Map<String, dynamic>]);
        pages = (data['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= pages);
      await _loadScoops(client);
      final list = [
        for (final j in items) fromApiJson(j, scoops: _scoops)
      ];
      (await SharedPreferences.getInstance())
          .setString(_kCache, jsonEncode(items));
      syncedAt.value = DateTime.now();
      return list;
    } on ApiException catch (e) {
      debugPrint('[ERROR][ProducerRepository.fetch] $e');
      lastError.value = e;
      rethrow;
    } finally {
      loading.value = false;
    }
  }

  /// Noms des SCOOP (id → nom).
  final _scoops = <String, String>{};

  Future<void> _loadScoops(ApiClient client) async {
    try {
      final data = await client.get('/scoops') as Map<String, dynamic>;
      final batch = data['items'] as List? ?? const [];
      for (final j in batch) {
        final m = j as Map<String, dynamic>;
        _scoops[m['id'].toString()] = m['name'].toString();
      }
    } catch (e) {
      debugPrint('[ERROR][ProducerRepository._loadScoops] $e');
    }
  }

  Future<void> clearCache() async {
    syncedAt.value = null;
    (await SharedPreferences.getInstance()).remove(_kCache);
  }

  /// Mapping `ProducerDto` OpenAPI → modèle UI.
  static Producer fromApiJson(
    Map<String, dynamic> j, {
    Map<String, String> scoops = const {},
  }) {
    final first = (j['firstName'] ?? '').toString().trim();
    final last = (j['lastName'] ?? '').toString().trim();
    final code = (j['code'] ?? j['id'] ?? '').toString();
    final initials =
        '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
            .toUpperCase();
    final phoneRaw =
        (j['phone'] ?? j['phoneMasked'] ?? '').toString().trim();
    final scoopName = scoops[j['scoopId']?.toString()] ?? '';
    final village = (j['village'] ?? '').toString().trim();
    final status = (j['status'] ?? '').toString();
    final quality = (j['quality'] ?? '').toString();
    final org = [
      if (scoopName.isNotEmpty) scoopName,
      if (status.isNotEmpty) status,
      if (quality.isNotEmpty) quality,
    ].join(' · ');

    return Producer(
      initials: initials.isEmpty ? '?' : initials,
      name: '$first $last'.trim().isEmpty ? code : '$first $last'.trim(),
      village: village.isEmpty ? (scoopName.isEmpty ? '—' : scoopName) : village,
      age: _parseAge(j['age']),
      tint: MockData.tints[code.hashCode.abs() % MockData.tints.length],
      code: code,
      phone: phoneRaw.isEmpty ? '—' : formatPhone(phoneRaw),
      sex: _parseSex(j['sex']),
      org: org.isEmpty ? '—' : org,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      remoteId: j['id']?.toString(),
      isNew: false,
    );
  }

  static int _parseAge(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final y = raw['years'] ?? raw['age'] ?? raw['value'];
      if (y is num) return y.toInt();
    }
    return int.tryParse('$raw') ?? 0;
  }

  static String _parseSex(dynamic raw) {
    final s = (raw ?? '').toString().toUpperCase();
    return switch (s) {
      'F' || 'FEMME' => 'Femme',
      'H' || 'M' || 'HOMME' => 'Homme',
      '' => '—',
      _ => raw.toString(),
    };
  }

  /// « +221771110001 » → « +221 77 111 00 01 ».
  static String formatPhone(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('221')) {
      final n = d.substring(3);
      return '+221 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5, 7)} ${n.substring(7)}';
    }
    // Masqué type 77 •• •• 12
    if (raw.contains('•') || raw.contains('*')) return raw;
    return raw;
  }

  /// « +221 77 111 00 01 » → « +221771110001 » (format attendu par l'API).
  static String? apiPhone(String? local) {
    if (local == null || local == '—' || local.contains('•')) return null;
    final d = local.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    return d.length == 9 ? '+221$d' : '+$d';
  }
}
