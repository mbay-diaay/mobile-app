import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/core/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/services/network_service.dart';
import 'app/services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Get.put(NetworkService(), permanent: true);
  await Get.putAsync(() => SessionService().init(), permanent: true);
  runApp(const MbayDiaayApp());
}

class MbayDiaayApp extends StatelessWidget {
  const MbayDiaayApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'Mbay Diaay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('fr', 'SN'),
        initialRoute: Routes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.cupertino,
        transitionDuration: Motion.page,
      );
}
