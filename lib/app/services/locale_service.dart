import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l’app (FR / WO). Persistance locale ; bascule depuis Profil.
class LocaleService extends GetxService {
  static const _kLocale = 'app_locale';

  final code = 'fr'.obs;

  Locale get locale =>
      code.value == 'wo' ? const Locale('wo', 'SN') : const Locale('fr', 'SN');

  String get label => code.value == 'wo' ? 'locale.wo'.tr : 'locale.fr'.tr;

  Future<LocaleService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocale);
    if (saved == 'wo' || saved == 'fr') code.value = saved!;
    return this;
  }

  Future<void> setLocale(String next) async {
    if (next != 'fr' && next != 'wo') return;
    code.value = next;
    await Get.updateLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, next);
  }

  Future<void> toggle() async {
    await setLocale(code.value == 'fr' ? 'wo' : 'fr');
  }
}
