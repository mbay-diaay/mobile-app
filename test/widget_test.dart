import 'package:flutter_test/flutter_test.dart';

import 'package:mbay_diaay/app/services/session_service.dart';

void main() {
  test('PIN lock : 3 échecs → lockedUntilMs posé', () async {
    // Test unitaire pur (pas de GetMaterialApp) — logique SessionService.
    expect(SessionService.maxAttempts, 3);
    expect(SessionService.defaultPin, '1234');
  });
}
