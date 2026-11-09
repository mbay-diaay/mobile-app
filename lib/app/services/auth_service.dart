import 'package:get/get.dart';

import 'api_client.dart';

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
}

/// Authentification mobile : sign-in (e-mail + mot de passe) → OTP → jetons → /me.
/// Les erreurs sont des [ApiException] (messages français via `userMessage`).
class AuthService extends GetxService {
  AuthService({ApiClient? client}) : _client = client ?? Get.find<ApiClient>();

  final ApiClient _client;

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
    return AuthUser.fromJson(map['user'] as Map<String, dynamic>);
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
  Future<AuthUser> me() async =>
      AuthUser.fromJson(await _client.get('/me') as Map<String, dynamic>);

  /// Déconnexion : prévient le serveur (sans bloquer hors ligne) puis jette les jetons.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {}
    await _client.clearTokens();
  }
}
