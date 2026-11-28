import 'dart:async';

import 'package:get/get.dart';

import 'api_client.dart';
import 'device_service.dart';
import 'local_producer_auth.dart';
import "package:flutter/foundation.dart";

/// Étape OTP en attente, renvoyée par `POST /auth/sign-in`.
class SignInChallenge {
  const SignInChallenge(
      {required this.id,
      required this.maskedEmail,
      required this.resendAvailableAt});

  final String id;
  final String maskedEmail;

  /// Moment (époque, ms) où le renvoi du code redevient possible.
  final int resendAvailableAt;

  factory SignInChallenge.fromJson(Map<String, dynamic> j) => SignInChallenge(
        id: j['challengeId'] as String,
        maskedEmail: (j['maskedEmail'] ?? '') as String,
        resendAvailableAt: (j['resendAvailableAt'] as num?)?.toInt() ?? 0,
      );

  /// Secondes à attendre avant de pouvoir demander un nouveau code.
  int get resendWaitSeconds {
    final ms = resendAvailableAt - DateTime.now().millisecondsSinceEpoch;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }
}

/// Utilisateur connecté (`user` d'`otp/verify`, `GET /me`).
class AuthUser {
  const AuthUser(
      {required this.id,
      required this.email,
      required this.name,
      required this.role,
      this.scoopId,
      this.scoopName,
      this.permissions = const []});

  final String id;
  final String email;
  final String name;
  final String role;
  final String? scoopId;
  final String? scoopName;
  final List<String> permissions;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        scoopId: j['scoopId'] as String?,
        scoopName: j['scoopName'] as String?,
        permissions: [
          for (final p in (j['permissions'] as List? ?? const [])) p as String
        ],
      );

  bool can(String permission) => permissions.contains(permission);

  /// Rôle exigé pour le parcours technicien.
  static const technicianRole = 'technicien';

  /// Rôle exigé pour le parcours producteur (même app).
  static const producerRole = 'producteur';
}

/// Authentification mobile technicien.
/// Parcours principal : téléphone + code 5 chiffres (`activate`) ou téléphone + mot de passe (`sign-in`).
/// Parcours test : e-mail + OTP. Erreurs : [ApiException] (`userMessage`).
class AuthService extends GetxService {
  AuthService({ApiClient? client}) : _client = client ?? Get.find<ApiClient>() {
    device = DeviceService(_client);
  }

  final ApiClient _client;

  /// Enregistrement de l'appareil : appelé après chaque connexion et à chaque lecture du profil.
  late final DeviceService device;

  /// Étape 1 : e-mail + mot de passe → défi OTP.
  Future<SignInChallenge> signIn(
      {required String email, required String password}) async {
    final data = await _client.post('/auth/sign-in',
        auth: false, body: {'email': email.trim(), 'password': password});
    return SignInChallenge.fromJson(data as Map<String, dynamic>);
  }

  /// Étape 2 : code OTP → jetons (conservés) + utilisateur.
  Future<AuthUser> verifyOtp(
      {required String challengeId, required String code}) async {
    final data = await _client.post('/auth/otp/verify',
        auth: false, body: {'challengeId': challengeId, 'code': code});
    final map = data as Map<String, dynamic>;
    await _client.setTokens(
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String?);
    unawaited(device.register());
    return AuthUser.fromJson(map['user'] as Map<String, dynamic>);
  }

  /// Première connexion d'un technicien : téléphone + code temporaire à 5 chiffres (remis en main
  /// propre par le gestionnaire) + mot de passe choisi. Renvoie directement les jetons.
  Future<AuthUser> activateTechnician(
      {required String phone,
      required String code,
      required String password}) async {
    final data = await _client.post('/auth/technician/activate',
        auth: false,
        body: {'phone': phone.trim(), 'code': code, 'password': password});
    return _keepSession(data as Map<String, dynamic>);
  }

  /// Connexions suivantes d'un technicien : téléphone + mot de passe, sans code par e-mail.
  Future<AuthUser> signInTechnician(
      {required String phone, required String password}) async {
    final data = await _client.post('/auth/technician/sign-in',
        auth: false, body: {'phone': phone.trim(), 'password': password});
    return _keepSession(data as Map<String, dynamic>);
  }

  /// Inscription producteur — API si dispo, sinon compte local (Keychain).
  Future<AuthUser> registerProducer({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    String? invitationCode,
  }) async {
    try {
      final data = await _client.post(
        '/auth/producer/register',
        auth: false,
        body: {
          'phone': phone.trim(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (invitationCode != null && invitationCode.isNotEmpty)
            'invitationCode': invitationCode.trim(),
        },
      );
      return _keepSession(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!_isProducerApiMissing(e)) rethrow;
      final local = Get.isRegistered<LocalProducerAuth>()
          ? Get.find<LocalProducerAuth>()
          : Get.put(LocalProducerAuth(), permanent: true);
      final user = await local.register(
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _keepLocalProducerSession(user);
      return user;
    }
  }

  /// Connexion producteur : téléphone + mot de passe (API ou vault local).
  Future<AuthUser> signInProducer(
      {required String phone, required String password}) async {
    try {
      final data = await _client.post('/auth/producer/sign-in',
          auth: false, body: {'phone': phone.trim(), 'password': password});
      return _keepSession(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!_isProducerApiMissing(e) && e.code != 'INVALID_CREDENTIALS') {
        rethrow;
      }
      final local = Get.isRegistered<LocalProducerAuth>()
          ? Get.find<LocalProducerAuth>()
          : Get.put(LocalProducerAuth(), permanent: true);
      // Si l’API répond INVALID_CREDENTIALS, on ne tombe pas en local
      // (compte serveur connu mais MDP faux).
      if (e.code == 'INVALID_CREDENTIALS' && !_isProducerApiMissing(e)) {
        rethrow;
      }
      final user = await local.signIn(phone: phone, password: password);
      if (user == null) {
        throw _isProducerApiMissing(e)
            ? const ApiException(
                'NOT_FOUND',
                'Aucun compte local pour ce numéro. Créez un compte ou attendez l’ouverture serveur.',
                status: 404,
              )
            : e;
      }
      await _keepLocalProducerSession(user);
      return user;
    }
  }

  bool _isProducerApiMissing(ApiException e) {
    final raw = e.message.toLowerCase();
    return e.status == 404 ||
        e.code == 'NOT_FOUND' ||
        e.isNetwork ||
        raw.contains('cannot post') ||
        raw.contains('/auth/producer') ||
        raw.contains('not found');
  }

  Future<void> _keepLocalProducerSession(AuthUser user) async {
    final token = '${ApiClient.localTokenPrefix}${user.id}';
    await _client.setTokens(accessToken: token, refreshToken: token);
  }

  /// Conserve les jetons de la réponse et renvoie l'utilisateur.
  Future<AuthUser> _keepSession(Map<String, dynamic> map) async {
    await _client.setTokens(
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String?);
    unawaited(device.register());
    return AuthUser.fromJson(
        (map['user'] as Map<String, dynamic>?) ?? const {});
  }

  /// Renvoie un code pour le même défi.
  Future<SignInChallenge> resendOtp(SignInChallenge c) async {
    final data = await _client
        .post('/auth/otp/resend', auth: false, body: {'challengeId': c.id});
    final map = data as Map<String, dynamic>;
    return SignInChallenge(
      id: (map['challengeId'] as String?) ?? c.id,
      maskedEmail: (map['maskedEmail'] as String?) ?? c.maskedEmail,
      resendAvailableAt: (map['resendAvailableAt'] as num?)?.toInt() ?? 0,
    );
  }

  /// Profil, rôle, SCOOP et permissions effectives.
  Future<AuthUser> me() async {
    final user =
        AuthUser.fromJson(await _client.get('/me') as Map<String, dynamic>);
    // Chaque ouverture de l'application met à jour la dernière activité de l'appareil.
    unawaited(device.register());
    return user;
  }

  /// Déconnexion : prévient le serveur (sans bloquer hors ligne) puis jette les jetons.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (e) {
      debugPrint("[ERROR][AuthService.logout] ${e}");
    }
    await _client.clearTokens();
  }
}
