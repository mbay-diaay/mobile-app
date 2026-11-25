import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'device_service.dart';
import 'network_service.dart';
import "package:flutter/foundation.dart";

/// Erreur renvoyée par l'API (`{ code, message, details? }`) ou par le réseau (`NETWORK`).
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status, this.details});

  final String code;
  final String message;
  final int? status;
  final dynamic details;

  bool get isNetwork => code == 'NETWORK';

  /// Message affichable à l'utilisateur, en français.
  String get userMessage => switch (code) {
        'NETWORK' => 'Pas de connexion. Vérifiez votre réseau et réessayez.',
        'INVALID_CREDENTIALS' => 'Identifiants incorrects.',
        'OTP_INVALID' => 'Code incorrect. Vérifiez et réessayez.',
        'OTP_EXPIRED' => 'Ce code a expiré. Demandez-en un nouveau.',
        'OTP_ATTEMPTS' => 'Trop de tentatives. Demandez un nouveau code.',
        'INVALID_ACTIVATION' => 'Numéro ou code invalide, ou code expiré.',
        'ACTIVATION_LOCKED' =>
          'Trop d\'essais : demandez un nouveau code à votre gestionnaire.',
        'RATE_LIMITED' => 'Trop de tentatives. Patientez un instant.',
        'DEVICE_REVOKED' =>
          'Cet appareil a été révoqué. Contactez votre gestionnaire.',
        'DEVICE_SIGNED_OUT' =>
          'Votre session a été fermée par votre gestionnaire. Reconnectez-vous.',
        'REFRESH_INVALID' ||
        'UNAUTHENTICATED' ||
        'UNAUTHORIZED' =>
          'Session expirée. Reconnectez-vous.',
        'FORBIDDEN' => "Vous n'avez pas accès à cette information.",
        'NOT_FOUND' => message.isEmpty
            ? 'Cette fonction n’est pas encore disponible sur le serveur.'
            : message,
        'BAD_REQUEST' => message.isEmpty
            ? 'Vérifiez les informations saisies.'
            : 'Vérifiez les informations saisies : $message',
        _ => message.isEmpty ? 'Une erreur est survenue.' : message,
      };

  @override
  String toString() => 'ApiException($code, $status, $message)';
}

/// Client HTTP de l'API Mbay Diaay : en-tête `Authorization`, jetons conservés dans le
/// stockage sécurisé de l'appareil, renouvellement automatique de la session sur 401.
class ApiClient extends GetxService {
  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
      : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _storage = storage ?? appSecureStorage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final String _baseUrl;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;
  String? _installationId;

  /// Dernier refus d'appareil (`DEVICE_REVOKED` ou `DEVICE_SIGNED_OUT`) reçu au renouvellement de la session.
  String? _deviceRefusal;

  /// Appelé quand la session ne peut plus être renouvelée (jeton refusé).
  void Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken != null;

  /// Identifiant d'installation de cet appareil, envoyé dans l'en-tête `X-Device-Id`.
  String? get installationId => _installationId;

  static const deviceRefusals = {'DEVICE_REVOKED', 'DEVICE_SIGNED_OUT'};

  /// Recharge les jetons enregistrés (au démarrage).
  Future<ApiClient> init() async {
    try {
      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
    } catch (e) {
      debugPrint("[ERROR][ApiClient.init] $e");
    }
    _installationId = await DeviceService.loadInstallationId(_storage);
    return this;
  }

  Future<void> setTokens({String? accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    try {
      if (accessToken != null) {
        await _storage.write(key: _kAccess, value: accessToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: _kRefresh, value: refreshToken);
      }
    } catch (e) {
      debugPrint("[ERROR][ApiClient.setTokens] $e");
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (e) {
      debugPrint("[ERROR][ApiClient.clearTokens] $e");
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        if (_installationId != null) 'X-Device-Id': _installationId!,
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
        queryParameters: query.map((k, v) => MapEntry(k, v.toString())));
  }

  /// Envoie la requête ; sur 401 (route protégée), renouvelle les jetons puis réessaie une fois.
  /// Renvoie le JSON décodé ou lève une [ApiException].
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    var res = await _send(method, path, body: body, query: query);
    if (res.statusCode == 401 && auth && _refreshToken != null) {
      // Appareil révoqué ou déconnecté par un administrateur : inutile de renouveler la session.
      final refusal = _deviceRefusalIn(res);
      if (refusal != null) return _endSessionOnRefusal(refusal, res);
      if (await _refresh()) {
        res = await _send(method, path, body: body, query: query);
      } else {
        final refused = _deviceRefusal;
        _deviceRefusal = null;
        await clearTokens();
        onSessionExpired?.call();
        if (refused != null) return _endSessionOnRefusal(refused, res);
      }
    }
    return _decodeOrThrow(res);
  }

  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, bool auth = true}) =>
      request('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      request('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body}) =>
      request('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      request('PUT', path, body: body);

  /// Envoi d'un fichier (multipart POST). Même renouvellement de session que [request].
  Future<dynamic> postFile(String path, String filePath,
          {String field = 'file'}) =>
      _multipart('POST', path, filePath, field: field);

  /// Envoi d'un fichier (multipart PUT) — ex. `PUT /producers/{id}/photo`.
  Future<dynamic> putFile(String path, String filePath,
          {String field = 'file'}) =>
      _multipart('PUT', path, filePath, field: field);

  Future<dynamic> _multipart(String method, String path, String filePath,
      {String field = 'file'}) async {
    if (Get.isRegistered<NetworkService>() &&
        !Get.find<NetworkService>().online.value) {
      throw const ApiException('NETWORK', 'Réseau indisponible');
    }
    Future<http.Response> once() async {
      final req = http.MultipartRequest(method, _uri(path))
        ..headers['Accept'] = 'application/json'
        ..files.add(await http.MultipartFile.fromPath(field, filePath));
      if (_accessToken != null) {
        req.headers['Authorization'] = 'Bearer $_accessToken';
      }
      if (_installationId != null) {
        req.headers['X-Device-Id'] = _installationId!;
      }
      try {
        final streamed = await req.send().timeout(ApiConfig.timeout * 3);
        return await http.Response.fromStream(streamed);
      } on TimeoutException {
        throw const ApiException('NETWORK', 'Délai dépassé');
      } on SocketException {
        throw const ApiException('NETWORK', 'Réseau indisponible');
      } on http.ClientException {
        throw const ApiException('NETWORK', 'Réseau indisponible');
      }
    }

    var res = await once();
    if (res.statusCode == 401 && _refreshToken != null && await _refresh()) {
      res = await once();
    }
    return _decodeOrThrow(res);
  }

  Future<http.Response> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query}) async {
    // Simulation hors ligne (Profil › Réseau) : aucune requête réseau.
    if (Get.isRegistered<NetworkService>() &&
        !Get.find<NetworkService>().online.value) {
      throw const ApiException('NETWORK', 'Réseau indisponible');
    }
    final req = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    try {
      final streamed = await req.send().timeout(ApiConfig.timeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('NETWORK', 'Délai dépassé');
    } on SocketException {
      throw const ApiException('NETWORK', 'Réseau indisponible');
    } on http.ClientException catch (e) {
      final m = e.message;
      // macOS / certains clients : « Cannot POST /v1/… » quand la route n’existe pas.
      final lower = m.toLowerCase();
      if (lower.contains('cannot post') ||
          lower.contains('cannot get') ||
          lower.contains('cannot put') ||
          lower.contains('cannot patch') ||
          lower.contains('cannot delete') ||
          m.contains('/auth/producer')) {
        throw ApiException('NOT_FOUND', m, status: 404);
      }
      throw const ApiException('NETWORK', 'Réseau indisponible');
    }
  }

  /// Une seule demande de renouvellement à la fois, même si plusieurs requêtes échouent ensemble.
  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() {
        _refreshing = null;
      });

  /// Renouvellement session — aligné doc authentification-mobile :
  /// seul un 401/403 (ou jeton invalide) déconnecte ; 429 / 5xx / réseau
  /// conservent les jetons (mode hors ligne / réessai).
  Future<bool> _doRefresh() async {
    try {
      final res = await _send('POST', '/auth/refresh',
          body: {'refreshToken': _refreshToken});
      if (res.statusCode == 401 || res.statusCode == 403) {
        _deviceRefusal = _deviceRefusalIn(res);
        return false;
      }
      // 429 / 5xx : garder la session (ne pas clearTokens).
      if (res.statusCode != 200 && res.statusCode != 201) return true;
      final data = jsonDecode(res.body);
      if (data is! Map) return false;
      final access = data['accessToken'] as String?;
      if (access == null) return false;
      await setTokens(
          accessToken: access,
          refreshToken: data['refreshToken'] as String? ?? _refreshToken);
      return true;
    } on ApiException catch (e) {
      // Réseau coupé : on garde la session.
      if (e.isNetwork) return true;
      // Autre erreur métier inattendue sur refresh : ne pas jeter la session
      // sauf codes d’auth explicites.
      if (e.code == 'REFRESH_INVALID' ||
          e.code == 'UNAUTHORIZED' ||
          e.code == 'UNAUTHENTICATED') {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[ERROR][ApiClient._doRefresh] $e');
      // Erreur inconnue : préférer garder la session (réessai possible).
      return true;
    }
  }

  /// Code d'appareil refusé (`DEVICE_REVOKED`, `DEVICE_SIGNED_OUT`) dans une réponse 401, sinon null.
  String? _deviceRefusalIn(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map) {
        final inner = data['details'];
        final code = (inner is Map ? inner['code'] : null) ?? data['code'];
        if (code is String && deviceRefusals.contains(code)) return code;
      }
    } catch (_) {
      // Corps illisible : pas un refus d'appareil.
    }
    return null;
  }

  /// Ferme la session et lève l'erreur dédiée, pour que l'écran affiche le bon message.
  Future<dynamic> _endSessionOnRefusal(String code, http.Response res) async {
    await clearTokens();
    onSessionExpired?.call();
    throw ApiException(code, '', status: res.statusCode);
  }

  dynamic _decodeOrThrow(http.Response res) {
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (e) {
        debugPrint("[ERROR][ApiClient._decodeOrThrow] $e");
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (data is Map && data['code'] is String) {
      // Préférer le code métier dans `details` (ex. INVALID_CREDENTIALS sous
      // un UNAUTHORIZED 401) pour afficher le bon message à l'utilisateur.
      final details = data['details'];
      final nested = details is Map ? details['code'] : null;
      final code = (nested is String && nested.isNotEmpty)
          ? nested
          : data['code'] as String;
      final message = (details is Map && details['message'] != null)
          ? details['message'].toString()
          : (data['message'] ?? '').toString();
      throw ApiException(code, message,
          status: res.statusCode, details: details);
    }
    throw ApiException('HTTP_${res.statusCode}', '', status: res.statusCode);
  }
}
