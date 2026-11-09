import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as geo;
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/app_theme.dart';
import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/buttons.dart';
import '../../widgets/layout.dart';
import '../../widgets/map_canvas.dart';
import '../../widgets/retry.dart';

/// Repère local de dessin : 3 unités = 1 m (même échelle que [indicativeHectares]).
/// Les mesures affichées (distances, surface) sont, elles, calculées sur la sphère
/// terrestre par maps_toolkit, à partir des coordonnées GPS des angles.
const double _unitsPerMeter = 3;

String _fmtM(double m) => m < 10
    ? '${m.toStringAsFixed(1).replaceAll('.', ',')} m'
    : '${m.round()} m';

/// Distance réelle (m) entre deux positions du repère local.
typedef _Meters = double Function(Offset a, Offset b);

/// 14 · 15 · 16a · 16 — relevé d'une parcelle, façon app « Mesures » d'iPhone.
///
/// La caméra arrière s'affiche en plein écran avec un réticule central : le
/// technicien marche jusqu'à chaque angle du champ, le vise et touche « + ».
/// Les angles sont posés au GPS réel (la réalité augmentée dérive sur des
/// hectares) ; la distance depuis le dernier angle s'affiche en direct.
/// L'onglet « Plan » montre le contour vu du dessus. Près du premier angle, le
/// réticule s'y aimante pour fermer. Signal faible (écran 15) : moyenne de
/// 5 mesures ; contour qui se croise (écran 16) : détecté à la pose.
class SurveyController extends GetxController {
  final Producer owner = (Get.arguments as Producer?) ?? MockData.producers[8];
  final String plotCode = Get.find<SessionService>().nextPlotCode();

  final points = <Offset>[].obs;
  final cursor = Offset.zero.obs;
  final accuracy = 99.0.obs; // en mètres
  final locating = true.obs;
  final closed = false.obs;
  final crossed = false.obs;
  final crossPoint = Rxn<Offset>();
  final measuring = 0.obs; // 0 = inactif, 1..5 = mesure en cours

  /// Localisation impossible (service coupé, accès refusé…) : message à l'écran.
  final gpsProblem = RxnString();
  bool _serviceOff = false;

  /// Vue plein écran : caméra (par défaut) ou plan vu du dessus.
  final showPlan = false.obs;
  final cameraOk = true.obs;

  /// Nombre d'angles conservés si l'on reprend après un croisement.
  int crossedAt = 0;

  static const weakAbove = 8.0; // m
  static const _snapUnits = 12.0; // 4 m

  StreamSubscription<Position>? _gps;
  Position? _origin;
  double _lat0 = 0, _lng0 = 0;
  final _samples = <Offset>[];

  bool get weak => accuracy.value > weakAbove;
  bool get snapping =>
      points.length >= 3 &&
      !closed.value &&
      !crossed.value &&
      (cursor.value - points.first).distance < _snapUnits;
  bool get canAdd =>
      gpsProblem.value == null &&
      !locating.value &&
      !crossed.value &&
      !closed.value &&
      !weak &&
      measuring.value == 0;
  bool get canFinish =>
      points.length >= 3 && !crossed.value && !weak && measuring.value == 0;

  /// Repère local → latitude/longitude (inverse de [_onFix]).
  geo.LatLng _geo(Offset u) {
    final m = u / _unitsPerMeter;
    return geo.LatLng(_lat0 - m.dy / 110540,
        _lng0 + m.dx / (111320 * math.cos(_lat0 * math.pi / 180)));
  }

  /// Distance réelle en mètres entre deux positions.
  double meters(Offset a, Offset b) =>
      geo.SphericalUtil.computeDistanceBetween(_geo(a), _geo(b)).toDouble();

  /// Point central du contour (moyenne des angles), seul repère que l'API enregistre.
  geo.LatLng? get _center {
    if (points.isEmpty) return null;
    final g = points.map(_geo).toList();
    return geo.LatLng(g.fold(0.0, (a, p) => a + p.latitude) / g.length,
        g.fold(0.0, (a, p) => a + p.longitude) / g.length);
  }

  /// Surface en hectares, sur la sphère terrestre.
  double get area => points.length < 3
      ? 0
      : geo.SphericalUtil.computeArea(points.map(_geo).toList()) / 10000;

  /// Distance (m) entre la position et le premier angle.
  double get toFirst => points.isEmpty ? 0 : meters(cursor.value, points.first);

  /// Périmètre en mètres (contour fermé dès 3 angles).
  double get perimeter {
    if (points.length < 2) return 0;
    final path = points.map(_geo).toList();
    if (points.length >= 3) path.add(path.first);
    return geo.SphericalUtil.computeLength(path).toDouble();
  }

  /// Pas de caméra (simulateur, accès refusé) : on reste sur le plan.
  void cameraUnavailable() {
    if (!cameraOk.value) return;
    cameraOk.value = false;
    showPlan.value = true;
    showToast('Caméra indisponible · affichage du plan',
        icon: Symbols.no_photography_rounded);
  }

  /// Méthode choisie au départ : 0 caméra, 1 plan, null = écran de choix.
  /// (La saisie manuelle n'est pas un mode : elle ouvre sa fiche puis enregistre.)
  final mode = Rxn<int>();

  /// Retour à l'écran de choix (par exemple quand le GPS est inutilisable).
  void backToPicker() {
    _gps?.cancel();
    gpsProblem.value = null;
    clear();
    mode.value = null;
  }

  /// Choix du départ. Caméra et plan démarrent le GPS ; la saisie manuelle ouvre sa fiche
  /// et, si on l'abandonne, on reste sur l'écran de choix.
  Future<void> choose(int m) async {
    if (m == 2) return openManual();
    showPlan.value = m == 1;
    mode.value = m;
    startGps();
  }

  // ───────── GPS

  /// Réglages GPS par plateforme : précision maximale, une position par seconde.
  static LocationSettings get _locationSettings =>
      switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.best,
            intervalDuration: const Duration(seconds: 1)),
        TargetPlatform.iOS => AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
          ),
        _ => const LocationSettings(accuracy: LocationAccuracy.best),
      };

  Future<void> startGps() async {
    gpsProblem.value = null;
    locating.value = true;
    try {
      _serviceOff = !await Geolocator.isLocationServiceEnabled();
      if (_serviceOff)
        return _problem('La localisation du téléphone est désactivée.');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return _problem("Mbay Diaay n'a pas accès à la position du téléphone.");
      }
    } catch (e) {
      debugPrint("[ERROR][Survey.startGps] ${e}");
      return _problem('GPS indisponible sur ce téléphone.');
    }
    if (isClosed) return;
    await _gps?.cancel();
    _gps = Geolocator.getPositionStream(locationSettings: _locationSettings)
        .listen(_onFix,
            onError: (_) => _problem('Le signal GPS a été interrompu.'));
  }

  void _problem(String message) {
    locating.value = false;
    measuring.value = 0;
    _samples.clear();
    gpsProblem.value = message;
  }

  /// Ouvre les réglages de localisation (service coupé) ou ceux de l'app (accès refusé).
  Future<void> openSettings() => _serviceOff
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();

  /// Position GPS → repère local en unités (x vers l'est, y vers le sud).
  void _onFix(Position p) {
    final o = _origin ??= p;
    _lat0 = o.latitude;
    _lng0 = o.longitude;
    final dx = (p.longitude - o.longitude) *
        111320 *
        math.cos(o.latitude * math.pi / 180);
    final dy = -(p.latitude - o.latitude) * 110540;
    final w = Offset(dx, dy) * _unitsPerMeter;
    cursor.value = w;
    accuracy.value = p.accuracy;
    locating.value = false;
    gpsProblem.value = null;
    if (measuring.value > 0) {
      _samples.add(w);
      if (_samples.length >= 5) {
        final avg =
            _samples.reduce((a, b) => a + b) / _samples.length.toDouble();
        _samples.clear();
        measuring.value = 0;
        showToast('Moyenne de 5 mesures enregistrée',
            icon: Symbols.my_location_rounded);
        _place(avg);
      } else {
        measuring.value = _samples.length + 1;
      }
    }
  }

  // ───────── Actions

  void addPoint() {
    if (!canAdd) return;
    if (snapping) return _close();
    _place(cursor.value);
  }

  void _place(Offset p) {
    final hit =
        points.length >= 2 ? _crossing(points.last, p, closing: false) : null;
    points.add(p);
    if (hit != null) return _markCrossed(points.length - 1, hit);
    HapticFeedback.mediumImpact();
  }

  void _close() {
    final hit = _crossing(points.last, points.first, closing: true);
    if (hit != null) return _markCrossed(points.length, hit);
    closed.value = true;
    HapticFeedback.heavyImpact();
  }

  void _markCrossed(int keep, Offset at) {
    crossedAt = keep;
    crossPoint.value = at;
    crossed.value = true;
    HapticFeedback.heavyImpact();
  }

  /// Premier croisement du segment [a, b] avec les côtés déjà tracés (hors côtés voisins).
  Offset? _crossing(Offset a, Offset b, {required bool closing}) {
    final n = points.length;
    for (var i = 0; i < n - 2; i++) {
      if (closing && i == 0) continue;
      final x = _intersect(a, b, points[i], points[i + 1]);
      if (x != null) return x;
    }
    return null;
  }

  static Offset? _intersect(Offset p, Offset p2, Offset q, Offset q2) {
    final r = p2 - p, s = q2 - q;
    final den = r.dx * s.dy - r.dy * s.dx;
    if (den.abs() < 1e-9) return null;
    final qp = q - p;
    final t = (qp.dx * s.dy - qp.dy * s.dx) / den;
    final u = (qp.dx * r.dy - qp.dy * r.dx) / den;
    const e = 1e-6;
    if (t <= e || t >= 1 - e || u <= e || u >= 1 - e) return null;
    return p + r * t;
  }

  /// Signal faible : 5 positions GPS, puis l'angle est posé à leur moyenne.
  void measureFive() {
    if (measuring.value > 0 || gpsProblem.value != null) return;
    _samples.clear();
    measuring.value = 1;
  }

  void undo() {
    if (crossed.value) return resume();
    if (closed.value) {
      closed.value = false;
      return;
    }
    if (points.isEmpty) return;
    points.removeLast();
    HapticFeedback.lightImpact();
  }

  void clear() {
    _samples.clear();
    measuring.value = 0;
    points.clear();
    closed.value = false;
    crossed.value = false;
    crossPoint.value = null;
  }

  void resume() {
    points.assignAll(points.take(crossedAt).toList());
    crossed.value = false;
    crossPoint.value = null;
    closed.value = false;
  }

  /// Saisie manuelle (secours sans GPS) : longueur × largeur en mètres, pour un
  /// champ rectangulaire. La parcelle est marquée « Surface déclarée ».
  Future<void> openManual() async {
    final mode = await Get.bottomSheet<String>(
      const _ModeSheet(),
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 380),
    );
    if (mode == 'points') return _manualPoints();
    if (mode == 'size') return _manualSize();
  }

  /// Envoie la parcelle au serveur (raison de l'erreur + « Réessayer » si ça échoue),
  /// puis l'ajoute à la fiche. Renvoie false si l'utilisateur abandonne.
  Future<bool> _commitPlot(Plot plot, double ha) async {
    final session = Get.find<SessionService>();
    String? id;
    saving.value = true;
    try {
      final ok = await runWithRetry(() async {
        id = await session.sendPlot(owner, plot);
      }, title: 'Parcelle non enregistrée');
      if (!ok) return false;
    } finally {
      saving.value = false;
    }
    session.addPlot(owner, id == null ? plot : plot.withRemoteId(id!), ha);
    return true;
  }

  /// Envoi en cours : bloque un second appui.
  final saving = false.obs;

  /// Saisie de points : latitude et longitude de chaque angle (« Me localiser » remplit
  /// avec le GPS). La surface est calculée sur la sphère à partir de ces points.
  Future<void> _manualPoints() async {
    final pts = await Get.bottomSheet<List<geo.LatLng>>(
      const _PointsSheet(),
      isScrollControlled: true,
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 420),
    );
    if (pts == null || pts.length < 3 || saving.value) return;
    final lat0 = pts.first.latitude, lng0 = pts.first.longitude;
    final local = [
      for (final p in pts)
        Offset(
            (p.longitude - lng0) *
                111320 *
                math.cos(lat0 * math.pi / 180) *
                _unitsPerMeter,
            -(p.latitude - lat0) * 110540 * _unitsPerMeter)
    ];
    final ha = geo.SphericalUtil.computeArea(pts) / 10000;
    final lat = pts.fold(0.0, (a, p) => a + p.latitude) / pts.length;
    final lng = pts.fold(0.0, (a, p) => a + p.longitude) / pts.length;
    final plot = Plot(
        plotCode,
        '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha',
        'Cultures à déclarer',
        'Points saisis',
        AppColors.blueSoft,
        AppColors.blueInk,
        areaHa: ha,
        lat: lat,
        lng: lng);
    if (!await _commitPlot(plot, ha)) return;
    Get.offNamed(Routes.surveyDone, arguments: {
      'points': _fitToViewBox(local),
      'owner': owner,
      'code': plotCode,
      'area': ha
    });
  }

  /// Saisie de la longueur et de la largeur (champ rectangulaire).
  Future<void> _manualSize() async {
    if (saving.value) return;
    final size = await Get.bottomSheet<Size>(
      const _ManualSheet(),
      isScrollControlled: true,
      barrierColor: const Color(0x8C0A140F),
      enterBottomSheetDuration: const Duration(milliseconds: 420),
    );
    if (size == null) return;
    final l = size.width, w = size.height;
    final ha = l * w / 10000;
    final plot = Plot(
        plotCode,
        '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha',
        'Cultures à déclarer',
        'Surface déclarée',
        AppColors.amberSoft,
        AppColors.amberInk,
        areaHa: ha);
    if (!await _commitPlot(plot, ha)) return;
    final rect = [
      Offset.zero,
      Offset(l * _unitsPerMeter, 0),
      Offset(l * _unitsPerMeter, w * _unitsPerMeter),
      Offset(0, w * _unitsPerMeter),
    ];
    Get.offNamed(Routes.surveyDone, arguments: {
      'points': _fitToViewBox(rect),
      'owner': owner,
      'code': plotCode,
      'area': ha
    });
  }

  Future<void> finish() async {
    if (!canFinish || saving.value) return;
    if (!closed.value) {
      final hit = _crossing(points.last, points.first, closing: true);
      if (hit != null) return _markCrossed(points.length, hit);
    }
    final ha = area;
    final plot = Plot(
        plotCode,
        '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha',
        'Cultures à déclarer',
        'Relevée',
        AppColors.blueSoft,
        AppColors.blueInk,
        areaHa: ha,
        lat: _center?.latitude,
        lng: _center?.longitude);
    if (!await _commitPlot(plot, ha)) return;
    Get.offNamed(Routes.surveyDone, arguments: {
      'points': _fitToViewBox(points),
      'owner': owner,
      'code': plotCode,
      'area': ha
    });
  }

  /// Ramène le contour dans le repère de dessin des écrans suivants (324 × 380).
  static List<Offset> _fitToViewBox(List<Offset> pts) {
    const vb = Size(324, 380), margin = 36.0;
    final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = math.max(maxX - minX, 1.0), h = math.max(maxY - minY, 1.0);
    final s =
        math.min((vb.width - 2 * margin) / w, (vb.height - 2 * margin) / h);
    final off = Offset((vb.width - w * s) / 2, (vb.height - h * s) / 2);
    return [for (final p in pts) off + (p - Offset(minX, minY)) * s];
  }

  /// Consigne affichée en haut, comme « Déplacez l'iPhone… » dans Mesures.
  (IconData, String) get hint {
    final n = points.length;
    if (gpsProblem.value != null)
      return (Symbols.location_off_rounded, 'Position indisponible');
    if (locating.value)
      return (Symbols.satellite_alt_rounded, 'Recherche du signal GPS…');
    if (crossed.value) return (Symbols.warning_rounded, 'Le contour se croise');
    if (closed.value)
      return (
        Symbols.check_circle_rounded,
        'Contour fermé · touchez ✓ pour enregistrer'
      );
    if (measuring.value > 0)
      return (
        Symbols.my_location_rounded,
        'Mesure ${measuring.value} / 5… restez immobile'
      );
    if (weak)
      return (
        Symbols.gps_off_rounded,
        'GPS imprécis (± ${accuracy.value.round()} m)'
      );
    if (snapping)
      return (Symbols.join_rounded, 'Touchez + pour fermer le contour');
    if (n == 0) return (Symbols.flag_rounded, 'Au premier angle, touchez +');
    return (
      Symbols.directions_walk_rounded,
      "Allez à l'angle ${n + 1}, puis touchez +"
    );
  }

  @override
  void onClose() {
    _gps?.cancel();
    super.onClose();
  }
}

// ───────────────────────────── Vue

class SurveyView extends GetView<SurveyController> {
  const SurveyView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final top = MediaQuery.paddingOf(context).top;
    return StatusBarStyle(
      dark: true,
      child: Scaffold(
        backgroundColor: _ground,
        body: Stack(children: [
          // Caméra en direct (par défaut) ou plan vu du dessus.
          Positioned.fill(
            child: Obx(() => AnimatedSwitcher(
                  duration: Motion.medium,
                  child: c.mode.value == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : c.showPlan.value
                          ? _Viewfinder(key: const ValueKey('plan'), c: c)
                          : _CameraView(key: const ValueKey('cam'), c: c),
                )),
          ),
          // Haut : fermer · précision GPS · effacer, puis la consigne.
          Positioned(
            top: top + 8,
            left: 14,
            right: 14,
            child: FadeSlideIn(
              offset: const Offset(0, -30),
              child: Column(children: [
                Row(children: [
                  _Glass(
                      onTap: Get.back,
                      child: const Sym(Symbols.close_rounded,
                          color: Colors.white)),
                  const Spacer(),
                  Obx(() => _Glass(
                        pill: true,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          PulseDot(
                              color: c.locating.value || c.weak
                                  ? AppColors.orange
                                  : AppColors.green,
                              size: 7),
                          const SizedBox(width: 6),
                          Text(
                              c.locating.value
                                  ? 'GPS…'
                                  : 'GPS ± ${c.accuracy.value.round()} m',
                              style: jakarta(12,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                      )),
                  const Spacer(),
                  Obx(() => AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: c.points.isEmpty ? .4 : 1,
                        child: _Glass(
                          onTap: c.points.isEmpty ? null : c.clear,
                          pill: true,
                          child: Text('Effacer',
                              style: jakarta(13,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      )),
                ]),
                const SizedBox(height: 14),
                Obx(() {
                  final (icon, text) = c.hint;
                  return AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (w, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                          scale: Tween(begin: .9, end: 1.0).animate(a),
                          child: w),
                    ),
                    child: _Glass(
                      key: ValueKey(text),
                      pill: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Sym(icon,
                            size: 18,
                            color: c.weak || c.crossed.value
                                ? AppColors.orange
                                : AppColors.lime),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(text,
                                style: jakarta(14,
                                    weight: FontWeight.w700,
                                    color: Colors.white))),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          ),
          // Bas : mesures, puis annuler · + · terminer (ou le panneau « contour croisé »).
          Align(
            alignment: Alignment.bottomCenter,
            child: Obx(() => AnimatedSwitcher(
                  duration: Motion.medium,
                  child: c.gpsProblem.value != null
                      ? _GpsProblem(key: const ValueKey('gps'), c: c)
                      : c.crossed.value
                          ? _CrossedSheet(key: const ValueKey('x'), c: c)
                          : _Controls(key: const ValueKey('ok'), c: c),
                )),
          ),
          // Écran de choix de la méthode, tant que rien n'est choisi.
          Positioned.fill(
            child: Obx(() => AnimatedSwitcher(
                  duration: Motion.medium,
                  child: c.mode.value == null
                      ? _ModePicker(key: const ValueKey('pick'), c: c)
                      : const SizedBox.shrink(key: ValueKey('done')),
                )),
          ),
        ]),
      ),
    );
  }
}

const _ground = Color(0xFF0B1611);

/// Vue « viseur » : le sol défile sous le réticule fixe, la caméra suit le
/// technicien et dézoome d'elle-même pour garder tout le contour à l'écran.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({super.key, required this.c});
  final SurveyController c;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Offset? _cam;
  double _scale = 2;
  double _time = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration t) {
    final c = widget.c;
    final pts = c.points;
    final showAll = (c.closed.value || c.crossed.value) && pts.length >= 3;
    final target = showAll
        ? pts.reduce((a, b) => a + b) / pts.length.toDouble()
        : c.cursor.value;
    var far = 0.0;
    for (final p in pts) {
      far = math.max(far, (p - target).distance);
    }
    final radius = math.min(_size.width, _size.height) * .36;
    final targetScale = pts.isEmpty || radius == 0
        ? 2.0
        : (radius / math.max(far, 30)).clamp(.5, 3.0);
    _cam = _cam == null ? target : Offset.lerp(_cam, target, .16);
    _scale = ui.lerpDouble(_scale, targetScale, .08)!;
    setState(() => _time = t.inMilliseconds / 1000);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        _size = box.biggest;
        final c = widget.c;
        return CustomPaint(
          size: box.biggest,
          painter: _SurveyPainter(
            meters: c.meters,
            points: c.points.toList(),
            cursor: c.cursor.value,
            cam: _cam ?? c.cursor.value,
            scale: _scale,
            time: _time,
            closed: c.closed.value,
            crossed: c.crossed.value,
            crossPoint: c.crossPoint.value,
            snapping: c.snapping,
            locating: c.locating.value,
            accuracy: c.accuracy.value,
            weak: c.weak,
          ),
        );
      });
}

class _SurveyPainter extends CustomPainter {
  _SurveyPainter({
    required this.points,
    required this.cursor,
    required this.cam,
    required this.scale,
    required this.time,
    required this.closed,
    required this.crossed,
    required this.crossPoint,
    required this.snapping,
    required this.locating,
    required this.accuracy,
    required this.weak,
    required this.meters,
  });
  final _Meters meters;

  final List<Offset> points;
  final Offset cursor;
  final Offset cam;
  final double scale;
  final double time;
  final bool closed;
  final bool crossed;
  final Offset? crossPoint;
  final bool snapping;
  final bool locating;
  final double accuracy;
  final bool weak;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _ground);
    final center = Offset(size.width / 2, size.height * .46);
    Offset s(Offset w) => center + (w - cam) * scale;

    // Quadrillage au sol (tous les 5 m) : il défile quand on marche.
    final step = 5 * _unitsPerMeter * scale;
    if (step > 10) {
      final o = s(Offset.zero);
      final grid = Paint()
        ..color = const Color(0x0FFFFFFF)
        ..strokeWidth = 1;
      for (var x = o.dx % step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (var y = o.dy % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    final pts = points.map(s).toList();
    final showReticle = !closed && !crossed;
    final reticle = snapping ? pts.first : center;
    final line = crossed ? AppColors.coral : Colors.white;
    final pulse = (time % 1.3) / 1.3;

    // Surface.
    if (pts.length >= 3) {
      canvas.drawPath(
        Path()..addPolygon(pts, true),
        Paint()
          ..color = (crossed ? AppColors.coral : AppColors.lime)
              .withValues(alpha: closed ? .3 : .14),
      );
    }

    // Côtés posés (avec une ombre, comme les traits de Mesures).
    final shadow = Paint()
      ..color = const Color(0x59000000)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final solid = Paint()
      ..color = line
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final sides = [
      for (var i = 0; i < pts.length - 1; i++)
        (pts[i], pts[i + 1], points[i], points[i + 1])
    ];
    if ((closed || crossed) && pts.length >= 3)
      sides.add((pts.last, pts.first, points.last, points.first));
    for (final (a, b, _, _) in sides) {
      canvas.drawLine(a, b, shadow);
      canvas.drawLine(a, b, solid);
    }

    // Côté en cours (pointillé vers le réticule) et fermeture prévue.
    if (showReticle && pts.isNotEmpty) {
      if (pts.length >= 2 && !snapping) {
        _dash(
            canvas,
            reticle,
            pts.first,
            Paint()
              ..color = AppColors.white(.3)
              ..strokeWidth = 1.5);
      }
      _dash(
          canvas,
          pts.last,
          reticle,
          Paint()
            ..color = const Color(0x59000000)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
      _dash(
          canvas,
          pts.last,
          reticle,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    }

    // Angles.
    for (var i = 0; i < pts.length; i++) {
      final first = i == 0 && pts.length >= 3;
      canvas.drawCircle(
          pts[i], first ? 8 : 6.5, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(pts[i], first ? 7 : 5.5,
          Paint()..color = first ? AppColors.lime : Colors.white);
      canvas.drawCircle(pts[i], first ? 3 : 2.2, Paint()..color = _ground);
    }

    // Longueur de chaque côté.
    for (final (a, b, wa, wb) in sides) {
      if ((b - a).distance > 56)
        _pill(canvas, (a + b) / 2, _fmtM(meters(wa, wb)));
    }

    // Point où le contour se coupe.
    if (crossPoint != null) {
      final x = s(crossPoint!);
      canvas.drawCircle(
          x,
          10 + 14 * pulse,
          Paint()
            ..color = AppColors.coral.withValues(alpha: .45 * (1 - pulse)));
      canvas.drawCircle(x, 9, Paint()..color = AppColors.coral);
      canvas.drawCircle(x, 3.5, Paint()..color = Colors.white);
    }

    if (!showReticle) return;

    // Précision GPS autour du réticule.
    final acc = accuracy * _unitsPerMeter * scale;
    canvas.drawCircle(
        center,
        acc,
        Paint()
          ..color = (weak ? AppColors.orange : Colors.white)
              .withValues(alpha: weak ? .14 : .06));
    canvas.drawCircle(
      center,
      acc,
      Paint()
        ..color = (weak ? AppColors.orange : Colors.white)
            .withValues(alpha: weak ? .6 : .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Réticule : cercle blanc et point central ; il s'aimante au premier angle.
    final ring = Paint()
      ..color = snapping ? AppColors.lime : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    if (locating) {
      final a = time * 4;
      canvas.drawArc(Rect.fromCircle(center: reticle, radius: 22), a,
          math.pi * 1.4, false, ring);
    } else {
      if (snapping) {
        canvas.drawCircle(
            reticle,
            26 + 6 * pulse,
            Paint()
              ..color = AppColors.lime.withValues(alpha: .3 * (1 - pulse)));
        canvas.drawCircle(reticle, 24,
            Paint()..color = AppColors.lime.withValues(alpha: .22));
      }
      canvas.drawCircle(
          reticle,
          snapping ? 24 : 22,
          Paint()
            ..color = const Color(0x40000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
      canvas.drawCircle(reticle, snapping ? 24 : 22, ring);
      canvas.drawCircle(reticle, 3.5,
          Paint()..color = snapping ? AppColors.lime : Colors.white);
    }

    // Distance en direct, sur le côté en cours.
    if (pts.isNotEmpty && !snapping) {
      final len = (reticle - pts.last).distance;
      final at =
          len > 90 ? (pts.last + reticle) / 2 : reticle - const Offset(0, 46);
      _pill(canvas, at, _fmtM(meters(cursor, points.last)), big: true);
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = (b - a).distance;
    if (d < 1) return;
    final dir = (b - a) / d;
    for (var x = 0.0; x < d; x += 14) {
      canvas.drawLine(a + dir * x, a + dir * math.min(x + 8, d), p);
    }
  }

  void _pill(Canvas canvas, Offset at, String text, {bool big = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: jakarta(big ? 15 : 11.5,
              weight: FontWeight.w800, color: AppColors.ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: at,
          width: tp.width + (big ? 22 : 14),
          height: tp.height + (big ? 10 : 6)),
      const Radius.circular(99),
    );
    canvas.drawRRect(
        r.shift(const Offset(0, 2)), Paint()..color = const Color(0x55000000));
    canvas.drawRRect(r, Paint()..color = Colors.white);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SurveyPainter old) => true;
}

/// Bas de l'écran : surface et périmètre, puis annuler · + · terminer.
class _Controls extends StatelessWidget {
  const _Controls({super.key, required this.c});
  final SurveyController c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 18 + MediaQuery.paddingOf(context).bottom),
        child: Obx(() {
          final n = c.points.length;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            if (c.weak) ...[
              FadeSlideIn(
                scale: .9,
                child: FlatButton(
                  label: c.measuring.value == 0
                      ? 'Mesurer 5 fois et faire la moyenne'
                      : 'Mesure ${c.measuring.value} / 5…',
                  icon: Symbols.replay_5_rounded,
                  bg: AppColors.amberSoft,
                  fg: AppColors.amberInk,
                  height: 46,
                  radius: 23,
                  size: 13,
                  weight: FontWeight.w800,
                  onTap: c.measureFive,
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Mesures du contour.
            if (n >= 3)
              CountUp(
                value: c.area,
                decimals: 2,
                prefix: '≈ ',
                suffix: ' ha',
                duration: const Duration(milliseconds: 500),
                style: display(34, color: Colors.white, height: 1),
                suffixStyle: jakarta(16,
                    weight: FontWeight.w700, color: AppColors.white(.7)),
              ),
            const SizedBox(height: 4),
            Text(
              n == 0
                  ? 'Aucun angle · ${c.plotCode}'
                  : '$n angle${n > 1 ? 's' : ''} · périmètre ${_fmtM(c.perimeter)}',
              style: jakarta(12,
                  weight: FontWeight.w600, color: AppColors.white(.65)),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              AnimatedOpacity(
                duration: Motion.fast,
                opacity: n == 0 && !c.closed.value ? .35 : 1,
                child: _Glass(
                    size: 54,
                    onTap: c.undo,
                    child: const Sym(Symbols.undo_rounded,
                        size: 24, color: Colors.white)),
              ),
              _Shutter(
                  enabled: c.canAdd, snapping: c.snapping, onTap: c.addPoint),
              AnimatedScale(
                scale: c.closed.value ? 1.1 : 1,
                duration: Motion.medium,
                curve: Curves.elasticOut,
                child: Pressable(
                  onTap: c.canFinish ? c.finish : null,
                  child: AnimatedContainer(
                    duration: Motion.medium,
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          c.canFinish ? AppColors.lime : AppColors.white(.12),
                    ),
                    child: Sym(Symbols.check_rounded,
                        size: 26,
                        color: c.canFinish
                            ? AppColors.forest
                            : AppColors.white(.35)),
                  ),
                ),
              ),
            ]),
          ]);
        }),
      );
}

/// Gros bouton rond « + », façon déclencheur de Mesures.
class _Shutter extends StatelessWidget {
  const _Shutter(
      {required this.enabled, required this.snapping, required this.onTap});
  final bool enabled;
  final bool snapping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: enabled ? onTap : null,
        scale: .88,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: enabled ? 1 : .4,
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5)),
            child: AnimatedContainer(
              duration: Motion.fast,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: snapping ? AppColors.lime : Colors.white),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  snapping ? Symbols.join_rounded : Symbols.add_rounded,
                  key: ValueKey(snapping),
                  size: 34,
                  weight: 600,
                  color: AppColors.forest,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pastille ou bouton rond en verre dépoli sombre.
class _Glass extends StatelessWidget {
  const _Glass(
      {super.key,
      required this.child,
      this.onTap,
      this.pill = false,
      this.size = 40,
      this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final bool pill;
  final double size;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: .9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: pill ? null : size,
              height: pill ? null : size,
              padding: pill
                  ? (padding ??
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9))
                  : null,
              alignment: pill ? null : Alignment.center,
              color: const Color(0x66000000),
              child: child,
            ),
          ),
        ),
      );
}

/// 16 · Le contour se croise : panneau rouge sombre.
class _CrossedSheet extends StatelessWidget {
  const _CrossedSheet({super.key, required this.c});
  final SurveyController c;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        offset: const Offset(0, 120),
        duration: const Duration(milliseconds: 650),
        curve: Motion.emphasized,
        child: Container(
          decoration: const BoxDecoration(
              color: AppColors.maroon,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Shake(
                trigger: 1,
                child: IconTile(Symbols.warning_rounded,
                    bg: AppColors.coral,
                    fg: AppColors.maroon,
                    iconSize: 24,
                    fill: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Le contour se croise',
                          style: jakarta(20,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              tracking: -.02)),
                      const SizedBox(height: 4),
                      Text(
                        "Deux traits se coupent après l'angle ${c.crossedAt}. Retournez à l'angle ${c.crossedAt} et refaites le tour dans l'ordre.",
                        style: jakarta(12,
                            color: AppColors.white(.75), height: 1.45),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            FlatButton(
              label: "Reprendre après l'angle ${c.crossedAt}",
              icon: Symbols.undo_rounded,
              bg: AppColors.coral,
              fg: AppColors.maroon,
              height: 58,
              size: 15,
              weight: FontWeight.w800,
              onTap: c.resume,
            ),
            const SizedBox(height: 12),
            FlatButton(
              label: 'Tout recommencer',
              bg: Colors.transparent,
              fg: Colors.white,
              border: AppColors.white(.3),
              height: 48,
              radius: 16,
              onTap: c.clear,
            ),
          ]),
        ),
      );
}

/// Viseur caméra : flux arrière en direct, réticule au centre et distance au
/// dernier angle. Qualité moyenne pour rester fluide
/// sur les téléphones anciens ; sans caméra, l'écran passe sur le plan.
class _CameraView extends StatefulWidget {
  const _CameraView({super.key, required this.c});
  final SurveyController c;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
          (x) => x.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      final cam =
          CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await cam.initialize();
      if (!mounted) {
        await cam.dispose();
        return;
      }
      setState(() => _cam = cam);
    } catch (e) {
      debugPrint("[ERROR][Survey._CameraView._start] ${e}");
      // Pas de caméra (simulateur) ou accès refusé.
      if (mounted) widget.c.cameraUnavailable();
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    final cam = _cam;
    if (mounted) setState(() => _cam = null);
    await cam?.dispose();
  }

  /// La caméra est libérée quand l'app passe en arrière-plan, reprise au retour.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    final c = widget.c;
    return Stack(fit: StackFit.expand, children: [
      if (cam == null || !cam.value.isInitialized)
        const ColoredBox(color: _ground)
      else
        // Remplit l'écran sans déformer (l'aperçu est fourni en paysage).
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize?.height ?? 720,
              height: cam.value.previewSize?.width ?? 1280,
              child: CameraPreview(cam),
            ),
          ),
        ),
      // Voiles haut et bas pour garder les textes lisibles en plein soleil.
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .22, .55, 1],
            colors: [
              Color(0x99000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0xCC000000)
            ],
          ),
        ),
      ),
      // Réticule et distance en direct, au centre comme dans Mesures.
      Align(alignment: const Alignment(0, -.08), child: _CameraReticle(c: c)),
    ]);
  }
}

/// Réticule du viseur caméra, avec la distance depuis le dernier angle et,
/// dès 3 angles, la distance jusqu'au premier (pour revenir fermer le contour).
class _CameraReticle extends StatelessWidget {
  const _CameraReticle({required this.c});
  final SurveyController c;

  @override
  Widget build(BuildContext context) => Obx(() {
        final n = c.points.length;
        final snap = c.snapping;
        final active = !c.closed.value && !c.crossed.value;
        final color =
            snap ? AppColors.lime : (c.weak ? AppColors.orange : Colors.white);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          // Distance depuis le dernier angle.
          AnimatedOpacity(
            duration: Motion.fast,
            opacity: active && n > 0 ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 10,
                      offset: Offset(0, 3))
                ],
              ),
              child: Text(
                  n == 0 ? '' : _fmtM(c.meters(c.cursor.value, c.points.last)),
                  style: jakarta(17,
                      weight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedScale(
            duration: Motion.medium,
            curve: Curves.elasticOut,
            scale: snap ? 1.2 : 1,
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: active ? 1 : .25,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: snap ? AppColors.lime.withValues(alpha: .25) : null,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 8)
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Retour au premier angle.
          AnimatedOpacity(
            duration: Motion.fast,
            opacity: active && n >= 3 ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0x8C000000),
                  borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Sym(Symbols.flag_rounded,
                    size: 14, color: AppColors.lime),
                const SizedBox(width: 5),
                Text(n >= 3 ? '1er angle à ${_fmtM(c.toFirst)}' : '',
                    style: jakarta(12,
                        weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]);
      });
}

/// Localisation impossible : on explique et on propose d'ouvrir les réglages.
class _GpsProblem extends StatelessWidget {
  const _GpsProblem({super.key, required this.c});
  final SurveyController c;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        offset: const Offset(0, 120),
        duration: const Duration(milliseconds: 650),
        curve: Motion.emphasized,
        child: Container(
          decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconTile(Symbols.location_off_rounded,
                  bg: AppColors.amberSoft,
                  fg: AppColors.amberInk,
                  iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Position indisponible',
                          style: jakarta(18,
                              weight: FontWeight.w800, tracking: -.02)),
                      const SizedBox(height: 4),
                      Obx(() => Text(
                            '${c.gpsProblem.value ?? ''} Le relevé a besoin du GPS pour mesurer la parcelle.',
                            style: jakarta(12.5,
                                color: AppColors.muted, height: 1.45),
                          )),
                    ]),
              ),
            ]),
            const SizedBox(height: 14),
            FlatButton(
              label: 'Ouvrir les réglages',
              icon: Symbols.settings_rounded,
              bg: AppColors.forest,
              fg: Colors.white,
              iconColor: AppColors.lime,
              height: 54,
              size: 15,
              weight: FontWeight.w800,
              onTap: c.openSettings,
            ),
            const SizedBox(height: 10),
            FlatButton(
                label: 'Réessayer',
                icon: Symbols.refresh_rounded,
                height: 48,
                radius: 16,
                onTap: c.startGps),
            const SizedBox(height: 10),
            FlatButton(
              label: 'Choisir une autre méthode',
              icon: Symbols.swap_horiz_rounded,
              bg: AppColors.sage,
              fg: AppColors.forest,
              height: 48,
              radius: 16,
              onTap: c.backToPicker,
            ),
          ]),
        ),
      );
}

/// Saisie manuelle : longueur × largeur (en mètres). Fonctionne hors ligne et
/// sans GPS ; la surface se calcule au fil de la frappe.
class _ManualSheet extends StatefulWidget {
  const _ManualSheet();

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  final _length = TextEditingController();
  final _width = TextEditingController();

  static double? _parse(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v != null && v > 0 && v <= 10000 ? v : null;
  }

  double? get _l => _parse(_length.text);
  double? get _w => _parse(_width.text);
  bool get _ok => _l != null && _w != null;

  @override
  void initState() {
    super.initState();
    _length.addListener(() => setState(() {}));
    _width.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController c,
          {bool autofocus = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: jakarta(10,
                    weight: FontWeight.w700, color: AppColors.muted)),
            TextField(
              controller: c,
              autofocus: autofocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(7)
              ],
              style: jakarta(24, weight: FontWeight.w800),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                suffixText: 'm',
                suffixStyle: jakarta(16,
                    weight: FontWeight.w700, color: AppColors.muted),
                hintText: '0',
                hintStyle: jakarta(24,
                    weight: FontWeight.w800, color: AppColors.faint),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = _l, w = _w;
    final ha = _ok ? l! * w! / 10000 : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const IconTile(Symbols.straighten_rounded,
                    bg: AppColors.sage, fg: AppColors.forest, iconSize: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saisir les dimensions',
                            style: jakarta(18,
                                weight: FontWeight.w800, tracking: -.02)),
                        Text('Champ rectangulaire · sans GPS ni réseau',
                            style: jakarta(12, color: AppColors.muted)),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _field('LONGUEUR', _length, autofocus: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×',
                      style: jakarta(22,
                          weight: FontWeight.w700, color: AppColors.muted)),
                ),
                _field('LARGEUR', _width),
              ]),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: Motion.medium,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                    color: _ok ? AppColors.lime : AppColors.sage,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _ok
                          ? 'Périmètre ${_fmtM(2 * (l! + w!))}'
                          : 'Entrez les deux mesures',
                      style: jakarta(12.5,
                          weight: FontWeight.w600, color: AppColors.forest),
                    ),
                  ),
                  if (_ok)
                    CountUp(
                      value: ha,
                      decimals: 2,
                      suffix: ' ha',
                      duration: const Duration(milliseconds: 400),
                      style: jakarta(24,
                          weight: FontWeight.w800,
                          tracking: -.02,
                          color: AppColors.forest),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: FlatButton(
                        label: 'Annuler',
                        height: 50,
                        radius: 16,
                        onTap: Get.back)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _ok ? 1 : .45,
                    child: FlatButton(
                      label: 'Enregistrer',
                      icon: Symbols.check_rounded,
                      iconColor: AppColors.lime,
                      bg: AppColors.forest,
                      fg: Colors.white,
                      height: 50,
                      radius: 16,
                      weight: FontWeight.w800,
                      onTap: _ok ? () => Get.back(result: Size(l!, w!)) : null,
                    ),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }
}

/// Choix du mode de saisie manuelle : dimensions du champ ou points GPS.
class _ModeSheet extends StatelessWidget {
  const _ModeSheet();

  Widget _tile(
          IconData icon, Color bg, String title, String sub, String result) =>
      Pressable(
        scale: .98,
        onTap: () => Get.back(result: result),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            IconTile(icon, bg: bg, fg: AppColors.forest),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: jakarta(14, weight: FontWeight.w700)),
                    Text(sub, style: jakarta(12, color: AppColors.muted)),
                  ]),
            ),
            const Sym(Symbols.chevron_right_rounded,
                size: 22, color: AppColors.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 18, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Saisir la parcelle à la main',
                    style:
                        jakarta(16, weight: FontWeight.w800, tracking: -.01)),
              ),
              _tile(
                  Symbols.pin_drop_rounded,
                  AppColors.lime,
                  'Points GPS',
                  'Latitude et longitude de chaque angle · surface calculée',
                  'points'),
              const SizedBox(height: 8),
              _tile(Symbols.straighten_rounded, AppColors.sage, 'Dimensions',
                  'Longueur × largeur d\'un champ rectangulaire', 'size'),
            ]),
      );
}

/// Une ligne de la saisie par points : latitude, longitude et « Me localiser ».
class _PointRow {
  final lat = TextEditingController();
  final lng = TextEditingController();
  bool locating = false;

  static double? _num(String s, double max) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v != null && v.abs() <= max ? v : null;
  }

  geo.LatLng? get point {
    final a = _num(lat.text, 90), o = _num(lng.text, 180);
    return a == null || o == null ? null : geo.LatLng(a, o);
  }

  void dispose() {
    lat.dispose();
    lng.dispose();
  }
}

/// Saisie des angles de la parcelle par latitude/longitude. Au moins 3 points, dans l'ordre
/// du tour du champ. « Me localiser » remplit le point avec la position GPS actuelle ; la
/// surface se calcule au fil de la saisie.
class _PointsSheet extends StatefulWidget {
  const _PointsSheet();

  @override
  State<_PointsSheet> createState() => _PointsSheetState();
}

class _PointsSheetState extends State<_PointsSheet> {
  final _rows = [_PointRow(), _PointRow(), _PointRow(), _PointRow()];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<geo.LatLng>? get _points {
    final pts = [for (final r in _rows) r.point];
    return pts.contains(null) ? null : [for (final p in pts) p!];
  }

  double get _ha {
    final pts = _points;
    return pts == null || pts.length < 3
        ? 0
        : geo.SphericalUtil.computeArea(pts) / 10000;
  }

  bool get _ok => _points != null && _ha > 0;

  Future<void> _locate(_PointRow r) async {
    setState(() => r.locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showToast('Activez la localisation du téléphone.',
            icon: Symbols.location_off_rounded);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        showToast("Accès à la position refusé. Autorisez-le dans les réglages.",
            icon: Symbols.block_rounded);
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 20)));
      r.lat.text = p.latitude.toStringAsFixed(6);
      r.lng.text = p.longitude.toStringAsFixed(6);
      if (p.accuracy > SurveyController.weakAbove) {
        showToast(
            'Signal faible (±${p.accuracy.round()} m) · réessayez à découvert.',
            icon: Symbols.signal_cellular_alt_1_bar_rounded);
      }
    } on TimeoutException {
      showToast('Position introuvable. Réessayez à découvert.',
          icon: Symbols.location_searching_rounded);
    } catch (e) {
      debugPrint("[ERROR][Survey._locate] ${e}");
      showToast('Position indisponible sur ce téléphone.',
          icon: Symbols.location_off_rounded);
    } finally {
      if (mounted) setState(() => r.locating = false);
    }
  }

  Widget _coord(String label, TextEditingController c) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: jakarta(9.5,
                    weight: FontWeight.w700, color: AppColors.muted)),
            TextField(
              controller: c,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                LengthLimitingTextInputFormatter(12)
              ],
              style: jakarta(15, weight: FontWeight.w800),
              decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '0.000000',
                  hintStyle: jakarta(15,
                      weight: FontWeight.w800, color: AppColors.faint)),
            ),
          ]),
        ),
      );

  Widget _row(int i) {
    final r = _rows[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.sage, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
          Text('Point ${i + 1}', style: jakarta(13, weight: FontWeight.w800)),
          const Spacer(),
          Pressable(
            onTap: r.locating ? null : () => _locate(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                r.locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.lime))
                    : const Sym(Symbols.my_location_rounded,
                        size: 16, color: AppColors.lime),
                const SizedBox(width: 6),
                Text(r.locating ? 'Recherche…' : 'Me localiser',
                    style: jakarta(12,
                        weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          if (_rows.length > 3) ...[
            const SizedBox(width: 6),
            Pressable(
              onTap: () => setState(() => _rows.removeAt(i).dispose()),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Sym(Symbols.close_rounded,
                    size: 18, color: AppColors.muted),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _coord('LATITUDE', r.lat),
          const SizedBox(width: 8),
          _coord('LONGITUDE', r.lng),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points;
    final ha = _ha;
    final perimeter = pts == null
        ? 0.0
        : geo.SphericalUtil.computeLength([...pts, pts.first]).toDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const IconTile(Symbols.pin_drop_rounded,
                bg: AppColors.lime, fg: AppColors.forest, iconSize: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saisir les points',
                        style: jakarta(18,
                            weight: FontWeight.w800, tracking: -.02)),
                    Text('3 points minimum, en faisant le tour du champ',
                        style: jakarta(12, color: AppColors.muted)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < _rows.length; i++) _row(i),
                if (_rows.length < 12)
                  Pressable(
                    onTap: () => setState(() => _rows.add(_PointRow())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.faint),
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Sym(Symbols.add_rounded,
                                size: 18, color: AppColors.forest),
                            const SizedBox(width: 6),
                            Text('Ajouter un point',
                                style: jakarta(13,
                                    weight: FontWeight.w700,
                                    color: AppColors.forest)),
                          ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: Motion.medium,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: _ok ? AppColors.lime : AppColors.sage,
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Expanded(
                child: Text(
                  _ok
                      ? 'Surface calculée · périmètre ${_fmtM(perimeter)}'
                      : pts == null
                          ? 'Remplissez tous les points'
                          : 'Les points ne forment pas une surface',
                  style: jakarta(12.5,
                      weight: FontWeight.w600, color: AppColors.forest),
                ),
              ),
              if (_ok)
                CountUp(
                  value: ha,
                  decimals: 2,
                  suffix: ' ha',
                  duration: const Duration(milliseconds: 400),
                  style: jakarta(24,
                      weight: FontWeight.w800,
                      tracking: -.02,
                      color: AppColors.forest),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          SwipeCta.dark(
            label: 'Glissez pour enregistrer',
            busyLabel: 'Enregistrement…',
            onConfirm: _ok ? () => Get.back(result: pts) : null,
          ),
        ]),
      ),
    );
  }
}

/// Écran d'accueil du relevé : trois façons de relever la parcelle.
class _ModePicker extends StatelessWidget {
  const _ModePicker({super.key, required this.c});
  final SurveyController c;

  Widget _option(int i, IconData icon, Color bg, String title, String text,
          {String? tag}) =>
      FadeSlideIn(
        delay: Motion.stagger(i, base: 180, step: 70),
        offset: const Offset(0, 26),
        child: Pressable(
          scale: .97,
          onTap: () => c.choose(i),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon,
                  size: 48,
                  radius: 16,
                  bg: bg,
                  fg: AppColors.forest,
                  iconSize: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(title,
                              style: jakarta(16,
                                  weight: FontWeight.w800, tracking: -.01)),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.lime,
                                borderRadius: BorderRadius.circular(99)),
                            child: Text(tag,
                                style: jakarta(10,
                                    weight: FontWeight.w800,
                                    color: AppColors.forest)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(text,
                          style: jakarta(12.5,
                              color: AppColors.muted, height: 1.35)),
                    ]),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Sym(Symbols.chevron_right_rounded,
                    size: 22, color: AppColors.faint),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _ground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FadeSlideIn(
                offset: const Offset(0, -20),
                child: _Glass(
                    onTap: Get.back,
                    child:
                        const Sym(Symbols.close_rounded, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Text('Comment relever\nla parcelle ?',
                    style: display(30, color: Colors.white, height: 1.1)),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: Text('Producteur · ${c.owner.name}',
                    style: jakarta(13, color: AppColors.white(.7))),
              ),
              const SizedBox(height: 22),
              _option(0, Symbols.photo_camera_rounded, AppColors.lime, 'Caméra',
                  "Visez chaque angle avec l'appareil photo et touchez +. Position GPS réelle.",
                  tag: 'Recommandé'),
              const SizedBox(height: 10),
              _option(1, Symbols.map_rounded, AppColors.sage, 'Plan',
                  'Marchez le long du champ et posez les angles sur un plan vu du dessus.'),
              const SizedBox(height: 10),
              _option(
                  2,
                  Symbols.edit_note_rounded,
                  AppColors.amberSoft,
                  'Saisie manuelle',
                  'Entrez les coordonnées de chaque angle, ou la longueur et la largeur du champ.'),
            ]),
          ),
        ),
      );
}
