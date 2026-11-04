import 'package:get/get.dart';

import '../core/app_theme.dart';
import '../modules/activation/download.dart';
import '../modules/activation/phone.dart';
import '../modules/activation/pin_create.dart';
import '../modules/activation/sms_code.dart';
import '../modules/lock/blocked.dart';
import '../modules/lock/revoked.dart';
import '../modules/lock/unlock.dart';
import '../modules/producer/new_producer.dart';
import '../modules/producer/producer_detail.dart';
import '../modules/producer/producer_space.dart';
import '../modules/shell/shell.dart';
import '../modules/splash/splash.dart';
import '../modules/survey/crops.dart';
import '../modules/survey/survey.dart';
import '../modules/survey/survey_done.dart';
import '../modules/sync/fix.dart';
import '../modules/sync/success.dart';
import '../modules/sync/sync.dart';
import 'app_routes.dart';
import 'slide_push_transition.dart';

/// Chaque famille d'écran a sa transition : pages poussées vers la gauche pour l'activation,
/// fondu-zoom pour les états d'alerte, montée par le bas pour les formulaires.
abstract final class AppPages {
  static final pages = <GetPage>[
    GetPage(
        name: Routes.splash,
        page: () => const SplashView(),
        binding: BindingsBuilder.put(() => SplashController())),
    GetPage(
      name: Routes.phone,
      page: () => const PhoneView(),
      binding: BindingsBuilder.put(() => PhoneController()),
      customTransition: SlidePushTransition(fadeIn: true),
      transitionDuration: Motion.slow,
    ),
    GetPage(
      name: Routes.smsCode,
      page: () => const SmsCodeView(),
      binding: BindingsBuilder.put(() => SmsCodeController()),
      customTransition: SlidePushTransition(),
    ),
    GetPage(
      name: Routes.pinCreate,
      page: () => const PinCreateView(),
      binding: BindingsBuilder.put(() => PinCreateController()),
      customTransition: SlidePushTransition(),
    ),
    GetPage(
      name: Routes.download,
      page: () => const DownloadView(),
      binding: BindingsBuilder.put(() => DownloadController()),
      customTransition: SlidePushTransition(),
    ),
    GetPage(
      name: Routes.unlock,
      page: () => const UnlockView(),
      binding: BindingsBuilder.put(() => UnlockController()),
      transition: Transition.fadeIn,
      transitionDuration: Motion.slow,
    ),
    GetPage(
      name: Routes.blocked,
      page: () => const BlockedView(),
      binding: BindingsBuilder.put(() => BlockedController()),
      transition: Transition.zoom,
    ),
    GetPage(
        name: Routes.revoked,
        page: () => const RevokedView(),
        transition: Transition.zoom),
    GetPage(
      name: Routes.shell,
      page: () => const ShellView(),
      binding: ShellBinding(),
      transition: Transition.fadeIn,
      transitionDuration: Motion.slow,
    ),
    GetPage(
        name: Routes.producer,
        page: () => const ProducerDetailView(),
        binding: BindingsBuilder.put(() => ProducerDetailController())),
    GetPage(
      name: Routes.newProducer,
      page: () => const NewProducerView(),
      binding: BindingsBuilder.put(() => NewProducerController()),
      transition: Transition.downToUp,
    ),
    GetPage(name: Routes.producerSpace, page: () => const ProducerSpaceView()),
    GetPage(
      name: Routes.survey,
      page: () => const SurveyView(),
      binding: BindingsBuilder.put(() => SurveyController()),
      transition: Transition.downToUp,
    ),
    GetPage(
        name: Routes.surveyDone,
        page: () => const SurveyDoneView(),
        transition: Transition.zoom),
    GetPage(
        name: Routes.crops,
        page: () => const CropsView(),
        binding: BindingsBuilder.put(() => CropsController())),
    GetPage(
        name: Routes.sync,
        page: () => const SyncView(),
        binding: BindingsBuilder.put(() => SyncController())),
    GetPage(
      name: Routes.fix,
      page: () => const FixView(),
      binding: BindingsBuilder.put(() => FixController()),
      transition: Transition.downToUp,
    ),
    // Transition standard (cupertino) : arrive de la droite en repoussant la page précédente,
    // repart vers la droite. Pas de retour par geste : la fiche est déjà enregistrée.
    GetPage(
        name: Routes.success,
        page: () => const SuccessView(),
        transition: Transition.cupertino,
        popGesture: false),
  ];
}
