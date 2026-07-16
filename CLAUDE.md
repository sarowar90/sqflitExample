# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Flutter-based offline Point-of-Sale (POS) app (Dart package name `sqflite_app`) that uses the device camera to scan QR codes and process retail sales. Store owners manage a product inventory, scan product QR codes at checkout to build a cart, complete sales transactions, and review the full sales history — all stored locally on-device with SQLite. There is no backend and no authentication.

## Commands

```bash
flutter pub get              # Install dependencies (run after editing pubspec.yaml)

flutter run -d android       # Run on a connected Android device/emulator (primary target — camera scanning)
flutter run -d windows       # Run on Windows desktop
flutter devices              # List available run targets

flutter analyze              # Static analysis / lint (flutter_lints, see analysis_options.yaml)
flutter test                 # Run the full test suite
flutter test test/widget_test.dart              # Run a single test file
flutter test --plain-name "smoke test"          # Run tests matching a name

flutter build apk            # Release Android build
```

`mobile_scanner` requires the camera permission; QR scanning only works on a device with a camera (a physical Android phone is the realistic target — desktop/web have no scannable camera flow). The `CAMERA` permission is declared automatically by the package on Android.

Note: `test/database_helper_test.dart` runs against a real SQLite database through `sqflite_common_ffi` (`sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi` in `setUpAll`); plain `sqflite` has no desktop implementation and would fail. `test/widget_test.dart` overrides `dbHelperProvider` with a `FakeDatabaseHelper` instead of touching SQLite.

## Architecture

Single-package Flutter app. All application code is under `lib/`; there are no feature modules or layers beyond the flat structure below.

**Data layer — `lib/database_helper.dart`.** `DatabaseHelper` is a singleton wrapping one SQLite database, `pos_database.db`, with two tables (schema below). It owns all SQL. The critical method is `sellProduct()`, which decrements product stock **and** inserts a sales-transaction row inside a single SQLite transaction so a sale is atomic — never edit these two writes to run independently.

**Models — `lib/models.dart`.** `Product` and `SaleTransaction` plain data classes with `toMap`/`fromMap` for SQLite round-tripping. `SaleTransaction` denormalizes `product_name` as a point-in-time snapshot, so renaming a product does not rewrite history.

**State — `lib/providers.dart` (Riverpod).** This is the hub connecting UI to the database; understand it before changing any screen behavior.

| Provider | Type | Role |
|---|---|---|
| `dbHelperProvider` | `Provider<DatabaseHelper>` | The singleton DB helper |
| `productListProvider` | `StateNotifierProvider<ProductListNotifier, List<Product>>` | Full product list; `addProduct`, `updateProduct`, `deleteProduct`, `loadProducts` |
| `searchQueryProvider` | `StateProvider<String>` | Inventory search text |
| `filteredProductsProvider` | `Provider<List<Product>>` | Derived filter of `productListProvider` by name/barcode/ID |
| `salesProvider` | `StateNotifierProvider<SalesNotifier, List<SaleTransaction>>` | Transaction log; `checkoutProduct` atomically sells then reloads **both** products and transactions |
| `scannedBarcodeProvider` | `StateProvider<String?>` | Most recently scanned barcode |
| `scannedProductProvider` | `FutureProvider.autoDispose<Product?>` | Resolves a scanned barcode to a `Product` via the DB |

Key data-flow rule: after a sale, `SalesNotifier.checkoutProduct` reloads product *and* transaction state so stock counts and the sales log stay consistent. Mutations that change stock or sales must go through the notifiers, not direct `DatabaseHelper` calls from widgets, or the in-memory state will drift from the DB.

**UI — `lib/main.dart`, `lib/theme.dart`, `lib/screens/`.** `main.dart` wraps the app in `ProviderScope` and renders `MainNavigationShell`, a `BottomNavigationBar` with four fixed tabs. `DashboardScreen` receives an `onTabChange(int)` callback so its quick-action buttons can switch tabs programmatically. `theme.dart` (`AppTheme`) defines the dark Material 3 palette, gradients, and Outfit/Share Tech Mono fonts via `google_fonts`.

| Tab | Screen (`lib/screens/`) | Purpose |
|---|---|---|
| Dashboard | `dashboard_screen.dart` | Gradient stat cards + quick actions (recent-sales list is commented out) |
| Scan POS | `sales_screen.dart` | Live `MobileScanner` QR scanner → cart → checkout + receipt; unknown barcodes trigger an inline "quick add" |
| Inventory | `product_list_screen.dart` | Searchable products, add/edit/delete; low-stock badge at quantity ≤ 5; auto-generates `PROD-XXXXXX` barcodes |
| Sales Log | `sales_history_screen.dart` | All transactions newest-first + aggregates; destructive "Reset DB" FAB |

`product_detail_screen.dart` is pushed via `Navigator.push` (not a tab) and renders a product's QR via `QrImageView`; its Print/Share buttons are simulated (UI feedback only).

## Database Schema (`pos_database.db`)

**products**: `id` INTEGER PK AUTOINCREMENT · `name` TEXT NOT NULL · `price` REAL NOT NULL · `quantity` INTEGER NOT NULL · `barcode` TEXT NOT NULL UNIQUE

**sales_transactions**: `id` INTEGER PK AUTOINCREMENT · `product_id` INTEGER NOT NULL · `product_name` TEXT NOT NULL (denormalized snapshot) · `quantity` INTEGER NOT NULL · `total_price` REAL NOT NULL · `timestamp` TEXT NOT NULL (ISO 8601)

## Notes / Gotchas

- **Unused learning artifacts:** `lib/models/greeting.dart` and `lib/services/greeting_service.dart` are leftover Dart practice exercises, not wired into the app. Safe to delete.
- **Dead code in DashboardScreen:** the recent-transactions `ListView.builder` is commented out; `_buildTransactionItem` and `_buildEmptyState` remain but are unused.
- **Reset DB is unguarded:** the Sales Log FAB deletes all products and transactions with confirmation only — there is no auth or backup.
- **Build warning:** `mobile_scanner` still applies the legacy Kotlin Gradle Plugin; builds fine today but future Flutter versions will reject it.
