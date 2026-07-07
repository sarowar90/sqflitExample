# Getting Started

## Prerequisites

- **Flutter SDK** (with Dart) installed and on your `PATH` — verify with `flutter doctor`.
- An **Android device or emulator** for the full QR-scanning flow (a physical phone is ideal).
- Optionally Windows desktop for non-camera UI work.

## Install dependencies

```bash
flutter pub get
```

Run this after any edit to `pubspec.yaml`.

## Run the app

```bash
flutter run -d android       # connected Android device/emulator (primary target — camera scanning)
flutter run -d windows       # Windows desktop
flutter devices              # list available run targets
```

!!! note "Scanning is Android-first"
    The live QR scanner (`mobile_scanner`) requires a camera. On desktop/web there is no
    scannable camera flow, so use Android for anything that touches the **Scan POS** tab.
    The `CAMERA` permission is declared automatically by the package on Android.

## Analyze, test, and build

```bash
flutter analyze                                  # static analysis / lint (flutter_lints)
flutter test                                     # run the full test suite
flutter test test/widget_test.dart              # run a single test file
flutter test --plain-name "smoke test"          # run tests matching a name
flutter build apk                                # release Android build
```

!!! warning "Default test still present"
    `test/widget_test.dart` is still the default Flutter counter test and does **not** match
    this app — it will fail if run as-is. Replace it before relying on `flutter test`.

## Project layout

```text
lib/
├── main.dart                # ProviderScope + MainNavigationShell (bottom nav)
├── theme.dart               # AppTheme: dark Material 3 palette, gradients, fonts
├── database_helper.dart     # DatabaseHelper singleton — owns all SQL
├── models.dart              # Product, SaleTransaction data classes
├── providers.dart           # Riverpod providers (UI ↔ DB hub)
└── screens/
    ├── dashboard_screen.dart
    ├── sales_screen.dart            # Scan POS
    ├── product_list_screen.dart     # Inventory
    ├── sales_history_screen.dart    # Sales Log
    └── product_detail_screen.dart   # pushed (not a tab)
```

!!! info "Leftover practice files"
    `lib/models/greeting.dart` and `lib/services/greeting_service.dart` are leftover Dart
    practice exercises, not wired into the app. The `lib/db/` and `lib/repositories/`
    folders are currently empty. These are safe to remove.
