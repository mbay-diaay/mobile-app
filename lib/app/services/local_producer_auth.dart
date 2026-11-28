import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'secure_storage.dart';

/// Comptes producteur locaux (Keychain) tant que `/auth/producer/*` n'est pas en prod.
/// Permet les tests Android / démo terrain sans bloquer sur l'API.
class LocalProducerAuth extends GetxService {
  static const _kVault = 'local_producer_accounts_v1';

  LocalProducerAuth({FlutterSecureStorage? storage})
      : _secure = storage ?? appSecureStorage;

  final FlutterSecureStorage _secure;

  Future<Map<String, Map<String, String>>> _load() async {
    try {
      final raw = await _secure.read(key: _kVault);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((phone, value) {
        final map = Map<String, String>.from(
            (value as Map).map((k, v) => MapEntry('$k', '$v')));
        return MapEntry(phone, map);
      });
    } catch (e) {
      debugPrint('[ERROR][LocalProducerAuth._load] $e');
      return {};
    }
  }

  Future<void> _save(Map<String, Map<String, String>> vault) async {
    await _secure.write(key: _kVault, value: jsonEncode(vault));
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[\s.\-]'), '').trim();

  Future<AuthUser> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final key = normalizePhone(phone);
    final vault = await _load();
    if (vault.containsKey(key)) {
      throw const ApiException(
        'PHONE_TAKEN',
        'Ce numéro a déjà un compte local. Connectez-vous.',
        status: 409,
      );
    }
    final id = 'local-prod-$key';
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    vault[key] = {
      'id': id,
      'password': password,
      'name': name,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
    };
    await _save(vault);
    return AuthUser(
      id: id,
      email: '',
      name: name,
      role: AuthUser.producerRole,
    );
  }

  Future<AuthUser?> signIn({
    required String phone,
    required String password,
  }) async {
    final key = normalizePhone(phone);
    final vault = await _load();
    final row = vault[key];
    if (row == null) return null;
    if (row['password'] != password) {
      throw const ApiException(
        'INVALID_CREDENTIALS',
        'Mot de passe incorrect.',
        status: 401,
      );
    }
    return AuthUser(
      id: row['id'] ?? 'local-prod-$key',
      email: '',
      name: row['name'] ?? 'Producteur',
      role: AuthUser.producerRole,
    );
  }
}
