import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbay_diaay/app/services/device_service.dart';

void main() {
  group('identifiant d\'installation', () {
    test('est un UUID v4', () {
      final id = newInstallationId();
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
              .hasMatch(id),
          isTrue,
          reason: id);
    });

    test('deux identifiants ne sont jamais identiques', () {
      final ids = {for (var i = 0; i < 50; i++) newInstallationId()};
      expect(ids.length, 50);
    });

    test('est reproductible avec la même graine (test seulement)', () {
      expect(newInstallationId(Random(7)), newInstallationId(Random(7)));
    });
  });

  group('réponse d\'enregistrement', () {
    test('lit active et resyncRequested', () {
      final registration = DeviceRegistration.fromJson(
          {'id': 'abc', 'active': false, 'resyncRequested': true});
      expect(registration.active, isFalse);
      expect(registration.resyncRequested, isTrue);
    });

    test('un appareil est actif par défaut', () {
      expect(DeviceRegistration.fromJson({'id': 'abc'}).active, isTrue);
    });
  });
}
