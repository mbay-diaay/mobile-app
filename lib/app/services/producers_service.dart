import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';
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
    try {
      final data = await _client.post('/producers', body: body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Upload photo CNI (une face). Champ multipart « file ».
  Future<bool> uploadCniPhoto(String producerId, String filePath) async {
    if (!canReachServer) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;
    final uri = Uri.parse('${ApiConfig.baseUrl}/producers/$producerId/cni/photo');
    final req = http.MultipartRequest('POST', uri);
    if (_client.accessToken != null) {
      req.headers['Authorization'] = 'Bearer ${_client.accessToken}';
    }
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send();
    return streamed.statusCode == 200 || streamed.statusCode == 201;
  }

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('221') && digits.length >= 12) return '+$digits';
    if (digits.length == 9) return '+221$digits';
    return raw.startsWith('+') ? raw : '+221$digits';
  }
}
