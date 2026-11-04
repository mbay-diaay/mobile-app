# AGENTS.md — Mbay Diaay

## Project Overview

Flutter + GetX field-technician app (offline prototype, no API calls). UI text and code comments in French. Based on "Mbay Diaay Mobile v2" mockup (forest green, lemon accent, cream background, big numbers, very rounded cards, expressive animations).

**Tech stack**: Flutter 3.27+, Dart ≥ 3.6, GetX 4.6.6, camera, geolocator, image_picker, maps_toolkit, shared_preferences, material_symbols_icons.

## Commands (essential)

```bash
flutter pub get                          # Install dependencies
flutter run                              # Run on Android or iOS (portrait only)
flutter analyze                          # Lints: flutter_lints + prefer_const_constructors / prefer_const_literals
dart format lib                          # Format code
```

- `flutter run` is portrait-only; all screens are portrait.
- No `test/` directory exists yet; if tests are added, run with `flutter test test/<file>_test.dart`.

## Architecture

- **One file per screen** in `lib/app/modules/<domain>/`: each file holds both the `GetxController` and the `GetView<Controller>`.
- **Domains**: `activation`, `lock`, `shell`, `producer`, `survey`, `sync`, `splash`.
- **`lib/main.dart`**: registers two permanent `GetxService`s (`NetworkService`, `SessionService`) before `runApp`, then starts `GetMaterialApp` at `Routes.splash`.
- **`SessionService`** is the in-memory "database" (`RxList`/`RxMap`): signed-in `TestAccount`, PIN, failed attempts (3 → blocked screen), producers, recently seen, pending uploads, issues to fix, plots and crops. Only activation (phone, PIN, `activated` flag) is persisted with `shared_preferences`.
- **`NetworkService.online`** simulates connectivity (`true.obs`, toggleable from Profil).
- **Seed data**: `app/data/mock_data.dart` (fictional producers, alerts, GPS contours, sync issues).
- **Design system** in `app/core/`:
  - `app_colors.dart` — palette (forest, lime, cream, ink, etc.).
  - `app_text.dart` — `jakarta()`, `mono()`, `display()` text helpers (Plus Jakarta Sans, JetBrains Mono, `tracking` in em).
  - `app_theme.dart` — `AppTheme.light` and `Motion` — durations `fast/medium/slow/page`, curves `spring/smooth/emphasized`, `Motion.stagger(i)` for cascading entrances. **Use these rather than literal durations/colors.**

## Routing

- Route names in `lib/app/routes/app_routes.dart` (`Routes.splash`, `Routes.phone`, `Routes.smsCode`, `Routes.pinCreate`, `Routes.download`, `Routes.unlock`, `Routes.blocked`, `Routes.revoked`, `Routes.shell`, `Routes.producer`, `Routes.newProducer`, `Routes.producerSpace`, `Routes.survey`, `Routes.surveyDone`, `Routes.crops`, `Routes.sync`, `Routes.fix`, `Routes.success`).
- **`lib/app/routes/app_pages.dart`** wires each `GetPage` with its binding (`BindingsBuilder.put(...)`) and a **per-family transition**:
  - Activation: `SlidePushTransition` (pages pushed left, carrefour effect).
  - Alerts/results: `Transition.zoom`.
  - Forms: `Transition.downToUp`.
  - Home/PIN: `Transition.fadeIn` / `Transition.cupertino`.
- Adding a screen: add route constant + `GetPage` entry + controller/view file.
- **Screen arguments** go through `Get.arguments` (a `Producer`, `SyncIssue`, `String` or `Map`). Controllers always fall back to a `MockData` value so each screen can open standalone.
- The generic `Routes.success` screen takes a map `{title, sub, cta, route, groups?}`.

## State Management

- **`SessionService`** (`lib/app/services/session_service.dart`) — the single source of truth for in-memory data:
  - `account` (`TestAccount` obs) — signed-in technician.
  - `pin` (`String obs`, default `'1234'`).
  - `activated` (`bool obs`) — whether activation (steps 01-04) is complete.
  - `failedAttempts` (`int obs`, max 3 → blocked screen).
  - `producers` (`<Producer> obs`) — all producers, immutable via `copyWith`.
  - `recent` (`<Producer> obs`) — recently viewed (max 3, synced by code via `SessionService._replace`).
  - `cropPlans` (`<String, Map<int, List<Crop>>> obs`) — plot code → season → `Crop`s (offline, restored on reopen).
  - `toFix` (`<SyncIssue> obs`) — items awaiting correction.
  - `pending` (`<PendingItem> obs`) — items pending upload.
  - `plots` (`<String, List<Plot>> obs`) — plot code → list of `Plot` (keyed by producer code).
- **Producers are immutable**: use `copyWith`. `SessionService._replace` keeps `producers`/`recent` in sync by comparing on `code`, not identity.
- **`SessionService.init()`** loads activation from `shared_preferences` before `runApp`. `completeActivation()` (end of screen 04) and `revoke()` (Profil › révocation) write/clear it.
- **`NetworkService`** (`lib/app/services/network_service.dart`): `online = true.obs`; `toggle()` flips it. Used to switch between online/offline home variants.
- **Controllers always fall back to `MockData`** so each screen can open standalone.

## Key Patterns & Conventions

| Pattern | Detail |
|---|---|
| **Wrong input → Shake** | Increment an `RxInt` (e.g., `shake.value++`) and wrap the widget in `Shake(trigger: controller.shake.value, child: ...)`. |
| **Primary action buttons** | Always `SwipeCta` / `SwipeCta.dark` (label "Glissez pour …", `busyLabel` while working). `CtaButton` is **no longer used** for screen actions. |
| **Entrance animations** | Staggered `FadeSlideIn`s with `Motion.stagger(i, step: 60, base: 80)` (or similar). Wrong input triggers `Shake`. |
| **Shell (5 tabs)** | `ShellController.tab` (obs) with direction-aware `AnimatedSwitcher`. Tab content must reserve `ShellView.bottomInset(context)` (92 + MediaQuery padding) for the floating nav bar. |
| **PIN keypad** | `PinKeypad` widget (in `pin_widgets.dart`). Dots fill elastically. Wrong PIN → `Shake`. 3 failures → `Routes.blocked`. |
| **Producer immutability** | Use `copyWith`. `SessionService._replace(old, updated)` syncs `producers` and `recent` by `code`. |
| **Crops per season** | `CropsController.plans` (`<RxList<Crop>>[2]`), saved to `SessionService.cropPlans` (plot code → season → `Crop`s). Reopening a plot restores them via `plotsOf()` / `_withCrops()`. Each non-empty season must total 100%. |
| **GPS/plot survey** | Real GPS only (`geolocator`, no demo mode). `maps_toolkit` for sphere computations. 3 local units = 1 m. Refit contour to 324×380 viewBox before passing to `survey_done`. Weak signal (> 8 m) locks "+" and offers 5-fix average. Self-crossing contours detected on placement (screen 16). Manual fallback: "Saisie" tab takes length × width in metres for rectangular fields. |
| **Network toggle** | Profil › "Réseau (simulation)" or the "Hors ligne" chip on home. |
| **Revocation** | Profil › "Simuler une révocation". |

## Design System — Colors, Text, Motion

**Colors** (from `app_colors.dart`): `forest = 0xFF0F3D2A`, `lime = 0xFFC6F05A`, `cream = 0xFFF5F2EA`, `ink = 0xFF0E1A14`, `coral = 0xFFFF6B6B`, `maroon = 0xFF2A1012`, `sage = 0xFFEEF3E4`, etc.

**Text styles** (from `app_text.dart`):
- `jakarta(size, {weight, color, tracking, height, style})` → Plus Jakarta Sans, `letterSpacing: tracking * size`.
- `mono(size, {weight, color, tracking})` → JetBrains Mono.
- `display(size, {color, height})` → `jakarta(size, weight: FontWeight.w800, color, tracking: -0.03, height: 1.05)`.

**Motion** (from `app_theme.dart`):
- `fast = 220ms`, `medium = 420ms`, `slow = 700ms`, `page = 520ms`.
- `spring = Curves.easeOutBack`, `smooth = Curves.easeOutCubic`, `emphasized = Cubic(.2, 0, 0, 1)`.
- `Motion.stagger(i, {step = 60, base = 80})` → `Duration(milliseconds: base + i * step)`.

## Widgets — Recommended & Anti-Patterns

**Always use** (from `app/widgets/`):
- `SwipeCta` / `SwipeCta.dark` for primary actions (label "Glissez pour …").
- `FadeSlideIn` for entrance animations.
- `Pressable` for touch feedback (scale on tap).
- `PulseDot` for breathing halo (network active, hors ligne).
- `Shake` for wrong input (PIN code, wrong crop total, etc.).
- `CountUp` for counting to a value with animation.
- `Chip2` for tags/labels (with optional dot indicator).
- `SquareIconButton.onDark` for actions on dark backgrounds.
- `StatusBarStyle(dark: true/false, child: ...)` for system UI styling.
- `FillScroll` for scrollable areas that fill remaining space.
- `DarkHeader` for forest-gradient topped sections.

**Avoid / one-shot usage**:
- `CtaButton` — no longer used for screen actions (kept for backward compat only).
- Do NOT mix animation durations/colors literals; always reference `AppTheme.light`, `Motion.*`, `AppColors.*`, `jakarta()`, `mono()`, `display()`.

## Common Gotchas

1. **`Get.arguments` type safety**: Screen arguments come through `Get.arguments` as the declared type. Controllers cast safely; if the argument might be null, default to `MockData`. Example:
   ```dart
   final p = ((Get.arguments as Producer?) ?? MockData.producers[5]).obs;
   ```

2. **PIN is shared across screens**: `SessionService.pin` is observed globally. The default is `'1234'` if skipped. Wrong PIN increments `failedAttempts`; 3 failures → `Routes.blocked`.

3. **`ShellView.bottomInset(context)`**: Tab content must reserve `92 + MediaQuery.paddingOf(context).bottom` pixels at the bottom for the floating nav bar. Forgetting this clips the bar or hides the last tab items.

4. **Producer edit/archive immutability**: When editing a producer, always use `copyWith`. The `updateProducer` method in `SessionService` replaces by `code` identity. Archived producers are read-only in lists but restorable from their detail view.

5. **Crop season total = 100%**: In `CropsController`, each non-empty season must total 100%. If a season is empty, the other must be 100% (or both empty triggers a shake). Use `_seasonOk(int s) => plans[s].isEmpty || _sum(plans[s]) == 100`.

6. **`CropSpec` vs `Crop`**: `CropSpec` is the catalog entry (short name, full name, tint, ink). `Crop` is a working copy with a `share` % that can be edited. `Crop.toCrop(n)` creates a `Crop` with `share = n`. When saving, call `session.declareCrops(code, {...})` which stores per-season lists.

7. **`SurveyController` GPS**: Real GPS only, no demo mode. `cameraUnavailable()` falls back to plan view. `openManual()` → `_ManualSheet` takes length × width for rectangular fields. Weak signal (> 8 m) offers 5-fix average. Self-crossing contours detected on placement (screen 16).

8. **`Motion.stagger` base/step**: The `base` is the first delay, `step` is the increment between items. E.g., `Motion.stagger(0, base: 200, step: 70)` gives 200, 270, 340, 410...

9. **`RxInt` shake threshold**: The `Shake` widget triggers when the `RxInt` value changes from its previous value (i.e., when you `increment` it). Reset it after the shake animation completes, or it will re-trigger.

10. **`SessionService._replace` compares by `code`**: When syncing producer `recent` list, the comparison is `x.code == old.code`, not identity. This means two producers with the same code are treated as the same.

## Screen Flow (01–25)

See `README.md` for the full diagram. Key entry/exit points:

- **01 Phone** → valid `77 123 45 67` / `78 111 22 33` → `Routes.smsCode`.
- **02 SMS code** → any 6 digits → `Routes.pinCreate`.
- **03 PIN create/confirm** → `Routes.download`.
- **04 Download** → `completeActivation()` → `Routes.unlock`.
- **05 Unlock** → PIN check → `Routes.shell` (5 tabs).
- **06 Blocked** → 3 PIN errors → `Routes.unlock` after retry.
- **07/08 Accueil** — offline (no network chip) / online (network chip, today stats).
- **09 Producteurs** — list/search, archived chip, floating +Fab.
- **10 Fiche producteur** — Infos/Parcelles/Alertes tabs, `···` menu (edit/archive/restore).
- **11/12 Nouveau producteur** — form, duplicate check ("Aliou Ba" in Mboro), CNI photos.
- **13 Carte** — map tab.
- **14-16** Survey — GPS parcel marking, camera or plan view, manual fallback.
- **17 Success** — generic recap, glide to return home or continue.
- **18-19 Crops** — per-season lists, 100% total, add/edit/remove/delete, save.
- **20-21 Sync** — online/offline status, pending items, send animation, fix issues.
- **22 À compléter** — TODO list from `SessionService.todoCount`.
- **23 Espace producteur** — aperçu de ce que voit le producteur connecté.
- **24 Profil** — changer PIN, réseau simulation, révocation.
- **25 Revoked** — phone désactivé, glissez pour réactiver → `Routes.phone`.