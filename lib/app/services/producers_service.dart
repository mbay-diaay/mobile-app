import 'package:get/get.dart';

import 'api_client.dart';
import 'network_service.dart';

/// Appels API producteurs (le serveur a le dernier mot sur validation / droits).
class ProducersService extends GetxService {
  ProducersService({ApiClient? client})
      : _client = client ?? Get.find<ApiClient>();

  final ApiClient _client;

  bool get canReachServer {
    final online = Get.isRegistered<NetworkService>()
        ? Get.find<NetworkService>().online.value
        : true;
    return online && _client.accessToken != null;
  }

  /// Crée un producteur sur le serveur. Renvoie le JSON safe, ou null si hors ligne / erreur.
  Future<Map<String, dynamic>?> create({
    required String firstName,
    required String lastName,
    String? village,
    String? phone,
    String? cni,
    String status = 'recensé',
  }) async {
    if (!canReachServer) return null;
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'status': status,
      if (village != null && village.isNotEmpty) 'village': village,
      if (phone != null && phone.isNotEmpty) 'phone': _normalizePhone(phone),
      if (cni != null && cni.trim().isNotEmpty) 'cni': cni.trim(),
    };
    // Les erreurs (ApiException) remontent à l'écran, qui les affiche et propose de réessayer.
    final data = await _client.post('/producers', body: body);
    return data is Map<String, dynamic> ? data : null;
  }

  /// Envoie une face de la CNI (multipart, champ « file »). Lève une [ApiException] en cas d'échec.
  Future<void> uploadCniPhoto(String producerId, String filePath) =>
      _client.postFile('/producers/$producerId/cni/photo', filePath);

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('221') && digits.length >= 12) return '+$digits';
    if (digits.length == 9) return '+221$digits';
    return raw.startsWith('+') ? raw : '+221$digits';
  }
}
