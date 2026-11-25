import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// État réseau : connectivité réelle + bascule manuelle (Profil › simulation).
class NetworkService extends GetxService {
  final online = true.obs;

  /// True si l’utilisateur force le hors-ligne depuis le profil.
  final simulatedOffline = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _deviceOnline = true;

  @override
  void onInit() {
    super.onInit();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _applyDevice(results);
      _sub = Connectivity().onConnectivityChanged.listen(_applyDevice);
    } catch (e) {
      debugPrint('[ERROR][NetworkService._bootstrap] $e');
      // Sans plugin : on reste en ligne (comportement historique).
      _deviceOnline = true;
      _publish();
    }
  }

  void _applyDevice(List<ConnectivityResult> results) {
    _deviceOnline = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
    _publish();
  }

  void _publish() {
    online.value = _deviceOnline && !simulatedOffline.value;
  }

  /// Bascule manuelle (Profil) : force hors ligne même si le réseau est OK.
  void toggle() {
    simulatedOffline.toggle();
    _publish();
  }

  @override
  void onClose() {
    unawaited(_sub?.cancel() ?? Future.value());
    super.onClose();
  }
}
