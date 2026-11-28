import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Trousseau partagé. Sur macOS desktop (debug sans signature), le Data
/// Protection Keychain exige des entitlements absents → on le désactive.
const appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
