/// Configuration de l'environnement API.
///
/// Production par défaut (utilisable sur un vrai téléphone). Pour viser une API locale :
/// `flutter run --dart-define=API_URL=http://10.0.2.2:3000/v1` (émulateur Android)
/// ou `--dart-define=API_URL=http://localhost:3000/v1` (simulateur iOS).
abstract final class ApiConfig {
  static const String productionBaseUrl = 'https://api.mbaydiaay.com/v1';

  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: productionBaseUrl);

  /// Délai maximum d'une requête avant de considérer le réseau indisponible.
  static const Duration timeout = Duration(seconds: 20);
}
