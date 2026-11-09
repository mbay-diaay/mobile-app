import 'package:get/get.dart';

import 'api_client.dart';

/// Service d'authentification mobile.
/// Flux : sign-in (email + mot de passe) → OTP verify → accessToken + refreshToken.
class AuthService extends GetxService {
  AuthService({ApiClient? client}) : _client = client ?? Get.find<ApiClient>();

  final ApiClient _client;

  /// Étape 1 : authentification avec email et mot de passe.
  /// Renvoie le challengeId pour la vérification OTP.
  Future<String?> signIn(
      {required String email, required String password}) async {
    final response = await _client
        .post('/auth/sign-in', body: {'email': email, 'password': password});
    if (response.statusCode != 200 && response.statusCode != 201) return null;
    final data = ApiClient.decode(response);
    return data?['challengeId'] as String?;
  }

  /// Étape 2 : vérification du code OTP à partir du challengeId.
  /// Renvoie true si l'authentification réussit et stocke les tokens.
  Future<bool> verifyOtp(
      {required String challengeId, required String otp}) async {
    final response = await _client.post('/auth/otp/verify',
        body: {'challengeId': challengeId, 'code': otp});
    if (response.statusCode != 200 && response.statusCode != 201) return false;
    final data = ApiClient.decode(response);
    final accessToken = data?['accessToken'] as String?;
    final refreshToken = data?['refreshToken'] as String?;
    if (accessToken == null) return false;
    _client.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    return true;
  }

  /// Renouvellement de la session à partir du refreshToken.
  Future<bool> refresh() async {
    final token = _client.refreshToken;
    if (token == null) return false;
    final response =
        await _client.post('/auth/refresh', body: {'refreshToken': token});
    if (response.statusCode != 200) return false;
    final data = ApiClient.decode(response);
    final accessToken = data?['accessToken'] as String?;
    final refreshToken = data?['refreshToken'] as String?;
    if (accessToken == null) return false;
    _client.setTokens(
        accessToken: accessToken, refreshToken: refreshToken ?? token);
    return true;
  }

  /// Récupération du profil de l'utilisateur connecté.
  Future<Map<String, dynamic>?> me() async {
    final response = await _client.get('/me');
    if (response.statusCode != 200) return null;
    return ApiClient.decode(response) as Map<String, dynamic>?;
  }

  /// Déconnexion.
  Future<void> logout() async {
    await _client.post('/auth/logout');
    _client.clearTokens();
  }
}
