import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Client HTTP pour l'API Mbay Diaay.
/// Gère automatiquement le header Authorization avec l'accessToken.
class ApiClient extends GetxService {
  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String _baseUrl;
  String? _accessToken;
  String? _refreshToken;

  String get baseUrl => _baseUrl;

  void setTokens({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

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

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async {
    return http.get(_uri(path, query), headers: _headers);
  }

  Future<http.Response> post(String path, {Object? body}) async {
    return http.post(_uri(path),
        headers: _headers, body: body == null ? null : jsonEncode(body));
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    return http.patch(_uri(path),
        headers: _headers, body: body == null ? null : jsonEncode(body));
  }

  Future<http.Response> delete(String path) async {
    return http.delete(_uri(path), headers: _headers);
  }

  /// Décodage JSON sûr : renvoie null si la réponse n'est pas du JSON valide.
  static dynamic decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }
}
