import '../core/app_colors.dart';
import 'mock_data.dart' show Crop;

/// Une culture du catalogue : abréviation, nom, couleur et variétés courantes
/// (simples suggestions : la variété reste libre).
class CropSpec {
  const CropSpec(this.short, this.name, this.palette,
      [this.varieties = const []]);
  final String short;
  final String name;
  final int palette;
  final List<String> varieties;

  Crop toCrop([int share = 0, String variety = '']) {
    final (tint, ink, bar) =
        CropCatalog.palettes[palette % CropCatalog.palettes.length];
    return Crop(short, name, variety, tint, ink, bar, share);
  }
}

/// Cultures maraîchères courantes dans les Niayes. Fonctionne hors ligne :
/// le catalogue est embarqué, et « Autre culture » permet d'en saisir une libre.
abstract final class CropCatalog {
  static const palettes = [
    (AppColors.purpleSoft, AppColors.purpleInk, AppColors.purple),
    (AppColors.lime, AppColors.forest, AppColors.forest),
    (AppColors.amberSoft, AppColors.amberInk, AppColors.orange),
    (AppColors.blueSoft, AppColors.blueInk, AppColors.blue),
    (AppColors.redSoft, AppColors.redInk, AppColors.red),
    (AppColors.sage, AppColors.forest, AppColors.green),
  ];

  static const all = [
    CropSpec('Au', 'Aubergine', 3,
        ['Kalenda F1', 'Black Beauty', 'Longue violette']),
    CropSpec('Be', 'Betterave', 4),
    CropSpec('Ca', 'Carotte', 2, ['Nantaise', 'Kuroda', 'Touchon']),
    CropSpec('Ch', 'Chou pommé', 1, ['KK Cross', 'Tropicana']),
    CropSpec('Co', 'Concombre', 5, ['Poinsett', 'Marketmore']),
    CropSpec('Cg', 'Courgette', 1),
    CropSpec('Go', 'Gombo', 5, ['Clemson', 'Kirikou']),
    CropSpec('Ha', 'Haricot vert', 5),
    CropSpec('Ja', 'Jaxatu', 0),
    CropSpec('La', 'Laitue', 1, ['Grand Rapids', 'Batavia']),
    CropSpec('Ma', 'Manioc', 2),
    CropSpec('Me', 'Melon', 2),
    CropSpec('Na', 'Navet', 0),
    CropSpec('Oi', 'Oignon', 0,
        ['Violet de Galmi', 'Noflaye', 'Texas Grano', 'Red Creole']),
    CropSpec('Pq', 'Pastèque', 4),
    CropSpec('Pa', 'Patate douce', 2),
    CropSpec('Pi', 'Piment', 4, ['Safi', 'Pili-pili']),
    CropSpec('Pv', 'Poivron', 5, ['California Wonder', 'Yolo Wonder']),
    CropSpec('PT', 'Pomme de terre', 3, ['Spunta', 'Diamant']),
    CropSpec('To', 'Tomate', 4, ['Roma', 'Mongal F1', 'Xina F1']),
  ];

  static CropSpec? byName(String name) {
    final n = name.trim().toLowerCase();
    for (final s in all) {
      if (s.name.toLowerCase() == n) return s;
    }
    return null;
  }

  /// Culture saisie librement : abréviation tirée du nom, couleur selon [index].
  static CropSpec custom(String name, int index) {
    final clean = name.trim();
    final letters = clean.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    final short = letters.isEmpty
        ? '?'
        : '${letters[0].toUpperCase()}${letters.length > 1 ? letters[1].toLowerCase() : ''}';
    return CropSpec(short, clean, index);
  }
}
