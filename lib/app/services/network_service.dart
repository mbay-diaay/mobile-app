import 'package:get/get.dart';

/// Simulation du réseau : basculée depuis le profil (« Réseau (simulation) »).
class NetworkService extends GetxService {
  final online = true.obs;

  void toggle() => online.toggle();
}
