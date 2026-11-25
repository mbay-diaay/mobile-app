import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/core/app_theme.dart';
import 'app/i18n/app_translations.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/data/local/app_database.dart';
import 'app/services/api_client.dart';
import 'app/services/auth_service.dart';
import 'app/services/locale_service.dart';
import 'app/services/local_producer_auth.dart';
import 'app/services/network_service.dart';
import 'app/services/outbox_service.dart';
import 'app/services/producer_repository.dart';
import 'app/services/producers_service.dart';
import 'app/services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Get.put(NetworkService(), permanent: true);
  Get.put(AppDatabase(), permanent: true);
  await Get.putAsync(() => LocaleService().init(), permanent: true);
  await Get.putAsync(() => SessionService().init(), permanent: true);
  await Get.putAsync(() => ApiClient().init(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(LocalProducerAuth(), permanent: true);
  Get.put(ProducerRepository(), permanent: true);
  Get.put(ProducersService(), permanent: true);
  Get.put(OutboxService(), permanent: true);
  final session = Get.find<SessionService>();
  final role = session.appRole.value;
  // Jetons orphelins (iOS garde le trousseau) : purge seulement hors parcours
  // producteur. Le producteur n’a pas de completeActivation — ses jetons doivent
  // survivre au cold start.
  if (role != AppRole.producer && !session.activated.value) {
    await Get.find<ApiClient>().clearTokens();
  }
  // Session refusée par l'API : retour au parcours du rôle courant.
  Get.find<ApiClient>().onSessionExpired = () {
    final r = Get.find<SessionService>().appRole.value;
    if (r == AppRole.producer) {
      if (Get.currentRoute == Routes.producerLogin ||
          Get.currentRoute == Routes.producerWelcome ||
          Get.currentRoute == Routes.authIntent) {
        return;
      }
      Get.offAllNamed(Routes.authIntent, arguments: AppRole.producer);
      return;
    }
    if (Get.currentRoute == Routes.phone) return;
    Get.offAllNamed(Routes.phone, arguments: {'reconnect': true});
  };
  // Annuaire local : technicien activé uniquement (pas le shell producteur).
  if (session.activated.value && role != AppRole.producer) {
    await session.restoreProducers();
  }
  runApp(const MbayDiaayApp());
}

class MbayDiaayApp extends StatelessWidget {
  const MbayDiaayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Get.find<LocaleService>();
    // Obx : reconstruit GetMaterialApp quand la langue change (Profil › Langue).
    return Obx(() {
      locale.code.value; // dépendance reactive
      return GetMaterialApp(
        title: 'Mbay Diaay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        translations: AppTranslations(),
        locale: locale.locale,
        fallbackLocale: const Locale('fr', 'SN'),
        initialRoute: Routes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.cupertino,
        transitionDuration: Motion.page,
      );
    });
  }
}
