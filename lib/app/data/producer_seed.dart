import '../services/auth_service.dart';

/// Compte producteur local (sans API) pour explorer le shell producteur en démo.
abstract final class ProducerSeed {
  static const phone = '770000000';
  static const phoneDisplay = '77 000 00 00';
  static const password = 'Demonstration2026';
  static const id = 'seed-producer';

  static const user = AuthUser(
    id: id,
    email: '',
    name: 'Aïssa Diop',
    role: AuthUser.producerRole,
    scoopName: 'SCOOP Démo Niayes',
  );

  /// Chiffres du téléphone, sans indicatif 221.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('221') && digits.length >= 12) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  static bool isSeedPhone(String phone) =>
      normalizePhone(phone) == ProducerSeed.phone;

  /// Téléphone seed + mot de passe démo (espaces / casse MDP ignorés sur les bords).
  static bool matches({required String phone, required String password}) {
    return isSeedPhone(phone) &&
        password.trim() == ProducerSeed.password;
  }
}
