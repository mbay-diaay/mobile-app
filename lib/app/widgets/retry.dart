import 'package:material_symbols_icons/symbols.dart';

import '../services/api_client.dart';
import 'confirm_sheet.dart';

/// Lance [action] ; si le serveur ou le réseau échoue, affiche la raison avec « Réessayer ».
/// Renvoie `true` quand l'action a réussi, `false` si l'utilisateur abandonne.
Future<bool> runWithRetry(Future<void> Function() action,
    {required String title}) async {
  while (true) {
    try {
      await action();
      return true;
    } catch (e) {
      final message =
          e is ApiException ? e.userMessage : 'Réponse inattendue du serveur.';
      final retry = await confirmSheet(
        title: title,
        message: message,
        confirmLabel: 'Réessayer',
        cancelLabel: 'Annuler',
        icon: Symbols.error_rounded,
      );
      if (!retry) return false;
    }
  }
}
