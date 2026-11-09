import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

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
        'INVALID_CREDENTIALS' => 'E-mail ou mot de passe incorrect.',
        'OTP_INVALID' => 'Code incorrect. Vérifiez et réessayez.',
        'OTP_EXPIRED' => 'Ce code a expiré. Demandez-en un nouveau.',
        'OTP_ATTEMPTS' => 'Trop de tentatives. Demandez un nouveau code.',
        'RATE_LIMITED' => 'Trop de tentatives. Patientez un instant.',
        'REFRESH_INVALID' ||
        'UNAUTHENTICATED' ||
        'UNAUTHORIZED' =>
          'Session expirée. Reconnectez-vous.',
        'FORBIDDEN' => "Vous n'avez pas accès à cette information.",
        'BAD_REQUEST' => 'Vérifiez les informations saisies.',
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
        _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final String _baseUrl;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  /// Appelé quand la session ne peut plus être renouvelée (jeton refusé).
  void Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken != null;

  /// Recharge les jetons enregistrés (au démarrage).
  Future<ApiClient> init() async {
    try {
      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
    } catch (_) {
      // Stockage illisible (ex. clé perdue) : on repart sans session.
    }
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
    } catch (_) {}
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {}
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
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
      if (await _refresh()) {
        res = await _send(method, path, body: body, query: query);
      } else {
        await clearTokens();
        onSessionExpired?.call();
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

  Future<http.Response> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query}) async {
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
    } on http.ClientException {
      throw const ApiException('NETWORK', 'Réseau indisponible');
    }
  }

  /// Une seule demande de renouvellement à la fois, même si plusieurs requêtes échouent ensemble.
  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() {
        _refreshing = null;
      });

  Future<bool> _doRefresh() async {
    try {
      final res = await _send('POST', '/auth/refresh',
          body: {'refreshToken': _refreshToken});
      if (res.statusCode != 200 && res.statusCode != 201) return false;
      final data = jsonDecode(res.body);
      final access = data['accessToken'] as String?;
      if (access == null) return false;
      await setTokens(
          accessToken: access,
          refreshToken: data['refreshToken'] as String? ?? _refreshToken);
      return true;
    } on ApiException {
      // Réseau coupé : on garde la session, la requête échouera avec NETWORK.
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _decodeOrThrow(http.Response res) {
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (data is Map && data['code'] is String) {
      throw ApiException(
          data['code'] as String, (data['message'] ?? '').toString(),
          status: res.statusCode, details: data['details']);
    }
    throw ApiException('HTTP_${res.statusCode}', '', status: res.statusCode);
  }
}
