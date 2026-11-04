# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Mbay Diaay is a Flutter + GetX field-technician app built from the "Mbay Diaay Mobile v2" mockup (forest green, lemon accent, cream background, big numbers, very rounded cards, highly expressive animations). It is an **offline prototype**: no API calls, test accounts only, and everything created lives in memory until the app is closed. UI text, code comments and the README are in French; keep new ones in French.

## Commands

```bash
flutter pub get
flutter run                 # Android or iOS (portrait only)
flutter analyze             # lints: flutter_lints + prefer_const_constructors / prefer_const_literals
dart format lib
```

Requires Flutter 3.27+ (Dart ≥ 3.6). There is no `test/` directory yet; if tests are added, run one with `flutter test test/<file>_test.dart` (or `--plain-name "<test name>"`). Fonts (Plus Jakarta Sans, JetBrains Mono) are bundled in `assets/fonts/`.

## Architecture

- `lib/main.dart` registers the two permanent `GetxService`s (`NetworkService`, `SessionService`) before `runApp`, then starts `GetMaterialApp` at `Routes.splash`.
- **One file per screen** in `lib/app/modules/<domain>/`: each file holds both the `GetxController` and the `GetView<Controller>`. Domains: `activation`, `lock`, `shell`, `producer`, `survey`, `sync`, `splash`.
- **Routing**: route names in `app/routes/app_routes.dart`; `app/routes/app_pages.dart` wires each `GetPage` with its binding (`BindingsBuilder.put(...)`) and a **per-family transition** (activation = `SlidePushTransition` in `routes/slide_push_transition.dart`, next page pushes the current one left; alerts/results = zoom, forms = downToUp, home/PIN = fadeIn). Adding a screen means: route constant + `GetPage` entry + controller/view file.
- **Screen arguments** go through `Get.arguments` (a `Producer`, `SyncIssue`, `String` or `Map`), and controllers always fall back to a `MockData` value so each screen can open standalone. The generic `Routes.success` screen takes a map `{title, sub, cta, route}`.
- **Shell** (`modules/shell/shell.dart`): a single route hosting 5 tabs (Accueil, Producteurs, Carte, À compléter, Profil) switched via `ShellController.tab` with a direction-aware `AnimatedSwitcher`, plus the floating nav bar. `ShellBinding` lazy-puts the tab controllers. Tab content must reserve `ShellView.bottomInset(context)` for the floating bar.
- **State**: `SessionService` is the in-memory "database" (`RxList`/`RxMap`): signed-in `TestAccount`, PIN and failed attempts (3 → blocked screen), producers, recently seen, pending uploads, issues to fix, plots and crops. Mutations go through its methods (`visit`, `addPlot`, `declareCrops`, `resolveIssue`, `markSent`, …). Only the activation (account phone, PIN, `activated` flag) is persisted with `shared_preferences`: `SessionService.init()` loads it before `runApp`, `completeActivation()` (end of screen 04) and `revoke()` (Profil › révocation) write/clear it, and the splash routes to `Routes.unlock` when activated, else `Routes.phone`. To replay onboarding, revoke or uninstall the app. `NetworkService.online` simulates connectivity.
- **Seed data**: `app/data/mock_data.dart` (fictional producers, alerts, GPS contours, sync issues).
- **Design system** in `app/core/`: `app_colors.dart`, `app_text.dart` (`jakarta()`, `mono()`, `display()` text helpers), `app_theme.dart` (`AppTheme.light` and `Motion` — durations `fast/medium/slow/page`, curves `spring/smooth/emphasized`, `Motion.stagger(i)` for cascading entrances). Use these rather than literal durations/colors.
- **Shared widgets** in `app/widgets/`: `animations.dart` (`FadeSlideIn`, `Pressable`, `Shake`, `PulseDot`, `CountUp`, …), `buttons.dart`, `pin_widgets.dart` (PIN keypad), `floating_nav.dart`, `map_canvas.dart` (map + plot contours), `ring_progress.dart`, `layout.dart` (`StatusBarStyle`, `FillScroll`, …). **Primary action buttons are always `SwipeCta` / `SwipeCta.dark` (label "Glissez pour …", `busyLabel` while working); `CtaButton` is no longer used for screen actions.** Screens compose these; entrance animations are staggered `FadeSlideIn`s, wrong input triggers `Shake` by incrementing an `RxInt`.

## Test data (from README)

- Phone: `77 123 45 67` (Ibrahima Diagne) or `78 111 22 33` (Awa Ndiaye); others are rejected.
- SMS code: `482913` (any 6 digits accepted). PIN: the one chosen at activation, `1234` if skipped.
- Crops of a plot (`modules/survey/crops.dart`): per-season working lists (`CropsController.plans`), saved to `SessionService.cropPlans` (plot code → season → `Crop`s) so reopening a plot restores them, and `plotsOf` derives each plot's displayed crops from it. Add from the embedded `CropCatalog` (`data/crop_catalog.dart`) or a free-text crop; tap a row to edit variety/share/change crop or delete; swipe to delete; each non-empty season must total 100 %. Fully offline.
- Producer edit/archive (`modules/producer/producer_detail.dart`, "···" menu): edit reopens `NewProducerView` in edit mode (pass the `Producer` as `Get.arguments`; it returns the updated one, with a discard confirmation when dirty); archive asks `confirmSheet` (`widgets/confirm_sheet.dart`) then sets `Producer.archived` via `SessionService.archiveProducer`. Lists use `activeProducers`; archived ones are reached from the Producteurs tab "Archivées" chip and restored from their (read-only) detail. Producers are immutable: use `copyWith`, and `SessionService._replace` keeps `producers`/`recent` in sync (compare by `code`, not identity).
- Duplicate flow: create "Aliou Ba" in Mboro.
- Plot survey (`modules/survey/survey.dart`, iPhone "Mesures"-style): live rear camera (`camera`, medium preset, falls back to the top-down plan if unavailable) with a centre reticle; corners come from real GPS only (`geolocator`, no demo mode). Distances/area/perimeter are computed on the sphere with `maps_toolkit` from the corners' lat/lng. Weak signal (> 8 m) locks "+" and offers a 5-fix average; self-crossing contours are detected on placement (screen 16). Local drawing units are 3 units = 1 m, refit to the 324×380 viewBox before being passed to `survey_done` along with the real `area`. Must work on old/low-end iOS and Android devices: no AR. Everything on this screen works offline (satellite GPS, camera, local `maps_toolkit` maths, no map tiles). A manual fallback ("Saisie" tab / GPS-problem panel → `_ManualSheet`) takes length × width in metres for rectangular fields and saves the plot with status "Surface déclarée".
- Network toggle: Profil › "Réseau (simulation)" or the "Hors ligne" chip on home. Revocation: Profil › "Simuler une révocation".

The README contains the full screen-flow diagram (screens numbered 01–25 matching the mockup).
