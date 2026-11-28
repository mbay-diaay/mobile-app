import 'package:get/get.dart';

import 'api_client.dart';
import 'network_service.dart';

/// Appels API producteurs alignés OpenAPI prod.
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

  /// Crée un producteur. **Absent** de OpenAPI prod → `NOT_FOUND` attendu.
  Future<Map<String, dynamic>?> create({
    required String firstName,
    required String lastName,
    String? village,
    String? phone,
    String? cni,
    String status = 'recensé',
  }) async {
    if (!canReachServer) {
      throw const ApiException('NETWORK', 'Réseau indisponible');
    }
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'status': status,
      if (village != null && village.isNotEmpty) 'village': village,
      if (phone != null && phone.isNotEmpty) 'phone': _normalizePhone(phone),
      if (cni != null && cni.trim().isNotEmpty) 'cni': cni.trim(),
    };
    final data = await _client.post('/producers', body: body);
    return data is Map<String, dynamic> ? data : null;
  }

  /// `PATCH /producers/{id}` — `UpdateProducerDto`.
  Future<void> update(
    String producerId, {
    String? firstName,
    String? lastName,
    String? village,
    String? phone,
    String? sex,
    int? age,
    String? status,
  }) async {
    await _client.patch('/producers/$producerId', body: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (village != null) 'village': village,
      if (phone != null && phone.isNotEmpty) 'phone': _normalizePhone(phone),
      if (sex != null) 'sex': sex,
      if (age != null) 'age': age,
      if (status != null) 'status': status,
    });
  }

  /// `POST /producers/{id}/corrections`.
  Future<void> submitCorrection(
    String producerId, {
    required List<Map<String, String>> changes,
    required String motif,
  }) =>
      _client.post('/producers/$producerId/corrections', body: {
        'changes': changes,
        'motif': motif,
      });

  /// Photo producteur : `PUT /producers/{id}/photo` (multipart).
  Future<void> uploadPhoto(String producerId, String filePath) =>
      _client.putFile('/producers/$producerId/photo', filePath);

  /// Ancien chemin CNI — redirige vers la photo producteur (contrat prod).
  Future<void> uploadCniPhoto(String producerId, String filePath) =>
      uploadPhoto(producerId, filePath);

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('221') && digits.length >= 12) return '+$digits';
    if (digits.length == 9) return '+221$digits';
    return raw.startsWith('+') ? raw : '+221$digits';
  }
}
