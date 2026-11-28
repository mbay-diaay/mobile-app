import 'package:get/get.dart';

import 'messages_fr.dart';
import 'messages_wo.dart';

/// Traductions GetX. FR = source. WO = FR + brouillons (pas de pseudo ~~~).
/// Règle projet : ne jamais inventer du wolof « définitif » sans relecture humaine.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr_SN': messagesFr,
        'wo_SN': messagesWo,
      };
}
