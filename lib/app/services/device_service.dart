import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'api_client.dart';

/// Version de l'application envoyée à l'API (à garder alignée sur `version` de `pubspec.yaml`).
const kAppVersion = '0.1.0';

/// Réponse de `POST /devices/register`.
class DeviceRegistration {
  const DeviceRegistration(
      {required this.id, required this.active, required this.resyncRequested});

  final String id;

  /// Faux : l'appareil a été révoqué par un administrateur.
  final bool active;

  /// Vrai une seule fois : un administrateur demande une resynchronisation.
  final bool resyncRequested;

  factory DeviceRegistration.fromJson(Map<String, dynamic> j) =>
      DeviceRegistration(
        id: (j['id'] ?? '') as String,
        active: (j['active'] ?? true) as bool,
        resyncRequested: (j['resyncRequested'] ?? false) as bool,
      );
}

/// Identifiant d'installation (UUID v4 aléatoire, jamais un identifiant matériel), généré au premier lancement et
/// gardé dans le stockage sécurisé. Il disparaît à la réinstallation : l'appareil est alors compté comme un nouvel appareil.
String newInstallationId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Enregistrement de l'appareil auprès de l'API (page « Appareils » du tableau de bord).
/// Voir `docs/INTEGRATION_APPAREILS.md` de l'API.
class DeviceService {
  DeviceService(this._client);

  static const _kInstallation = 'installation_id';

  final ApiClient _client;

  /// Mis à vrai quand un administrateur demande une resynchronisation (une seule fois par demande).
  final resyncRequested = false.obs;

  /// Charge (ou génère puis garde) l'identifiant d'installation.
  static Future<String> loadInstallationId(FlutterSecureStorage storage) async {
    try {
      final saved = await storage.read(key: _kInstallation);
      if (saved != null && saved.length >= 8) return saved;
      final created = newInstallationId();
      await storage.write(key: _kInstallation, value: created);
      return created;
    } catch (e) {
      debugPrint('[ERROR][DeviceService.loadInstallationId] $e');
      // Stockage indisponible : un identifiant pour cette exécution seulement.
      return newInstallationId();
    }
  }

  /// Dit à l'API que cet appareil est utilisé. À appeler après la connexion et à chaque ouverture.
  /// Un appareil révoqué perd sa session. Les erreurs réseau sont ignorées : l'appel sera refait plus tard.
  Future<void> register() async {
    final installationId = _client.installationId;
    if (installationId == null || !_client.hasSession) return;
    try {
      final data = await _client.post('/devices/register', body: {
        'installationId': installationId,
        if (Platform.isAndroid || Platform.isIOS)
          'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': kAppVersion,
      });
      final result = DeviceRegistration.fromJson(data as Map<String, dynamic>);
      if (!result.active) {
        await _client.clearTokens();
        _client.onSessionExpired?.call();
        return;
      }
      if (result.resyncRequested) resyncRequested.value = true;
    } on ApiException catch (e) {
      debugPrint('[ERROR][DeviceService.register] $e');
    } catch (e) {
      debugPrint('[ERROR][DeviceService.register] $e');
    }
  }
}
