import 'session_service.dart';

/// Un technicien créé par son téléphone reçoit une adresse technique, jamais montrée.
const _syntheticEmailSuffix = '@technicien.mbaydiaay.local';

extension AccountContact on TestAccount {
  /// Adresse technique générée par l'API pour un compte sans e-mail.
  bool get hasSyntheticEmail => email.endsWith(_syntheticEmailSuffix);

  /// Contact à afficher : l'e-mail réel, ou rien pour une adresse technique.
  String get displayContact => hasSyntheticEmail ? '' : email;
}
