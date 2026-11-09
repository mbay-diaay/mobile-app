import 'package:flutter/foundation.dart';

/// Configuration de l'environnement API.
/// Bascule entre local et production selon le mode de build.
abstract final class ApiConfig {
  static const String localBaseUrl = 'http://localhost:3000/v1';
  static const String productionBaseUrl = 'https://api.mbaydiaay.com/v1';

  /// En debug, on utilise l'API locale ; en release, l'API de production.
  static String get baseUrl => kReleaseMode ? productionBaseUrl : localBaseUrl;
}
