# QR Code POS — Project Documentation

## Overview
A Flutter-based offline Point-of-Sale (POS) app that uses the device camera to scan QR codes and process retail sales. Store owners can manage a product inventory, scan product QR codes at checkout to build a cart, complete sales transactions, and review the full sales history — all stored locally on-device with SQLite.

## Tech Stack
- **Flutter SDK:** `^3.11.5` (Dart)
- **State management:** Riverpod (`flutter_riverpod: ^2.5.1`)
- **Local database:** sqflite (`^2.4.3`) with `path: ^1.9.1`
- **QR code generation:** `qr_flutter: ^4.1.0`
- **QR/barcode scanning:** `mobile_scanner: ^7.2.0`
- **Fonts:** `google_fonts: ^6.2.1` (Outfit + Share Tech Mono)
- **Icons:** `cupertino_icons: ^1.0.8`

## Project Structure
```
lib/
  main.dart              — App entry point; ProviderScope, MaterialApp (dark theme), 4-tab bottom nav shell
  theme.dart             — AppTheme: dark color palette, gradients, Material 3 ThemeData (Outfit font)
  providers.dart         — All Riverpod providers and StateNotifiers
  models.dart            — Product and SaleTransaction data models (used by the main app)
  database_helper.dart   — Main DatabaseHelper singleton: products + sales_transactions schema and queries

  models/
    greeting.dart        — Greeting model (id, message, language, category) — learning exercise, not used by the main app

  services/
    greeting_service.dart — In-memory singleton with 12 multilingual greetings; getRandom, getAll, filter by language/category — learning exercise, not used by the main app

  screens/
    dashboard_screen.dart      — Home tab: stat cards, quick-action buttons, recent sales list
    sales_screen.dart          — Scan POS tab: live QR scanner, cart management, checkout + receipt
    product_list_screen.dart   — Inventory tab: searchable product list, add/edit/delete dialogs
    product_detail_screen.dart — QR code display for a product; print/share simulation (push route)
    sales_history_screen.dart  — Sales Log tab: all transactions, aggregate metrics, DB reset button
```

## Database Schema

### `pos_database.db` (lib/database_helper.dart — main app)

**products**
| Column     | Type    | Constraints              |
|------------|---------|--------------------------|
| id         | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name       | TEXT    | NOT NULL                 |
| price      | REAL    | NOT NULL                 |
| quantity   | INTEGER | NOT NULL                 |
| barcode    | TEXT    | NOT NULL UNIQUE           |

**sales_transactions**
| Column        | Type    | Constraints              |
|---------------|---------|--------------------------|
| id            | INTEGER | PRIMARY KEY AUTOINCREMENT |
| product_id    | INTEGER | NOT NULL                 |
| product_name  | TEXT    | NOT NULL (denormalized snapshot) |
| quantity      | INTEGER | NOT NULL                 |
| total_price   | REAL    | NOT NULL                 |
| timestamp     | TEXT    | NOT NULL (ISO 8601)      |

`sellProduct()` runs both the stock decrement and the transaction insert inside a single SQLite transaction to guarantee atomicity.

## Navigation

`MainNavigationShell` renders a `BottomNavigationBar` with four fixed tabs:

| Index | Label      | Icon                  | Screen                |
|-------|------------|-----------------------|-----------------------|
| 0     | Dashboard  | `Icons.dashboard`     | `DashboardScreen`     |
| 1     | Scan POS   | `Icons.qr_code_scanner` | `SalesScreen`       |
| 2     | Inventory  | `Icons.inventory_2`   | `ProductListScreen`   |
| 3     | Sales Log  | `Icons.history_edu`   | `SalesHistoryScreen`  |

`DashboardScreen` receives an `onTabChange(int)` callback so the quick-action buttons can switch tabs programmatically.

## Screens

- **DashboardScreen** (`screens/dashboard_screen.dart`) — Shows four gradient stat cards (total products, low-stock count, total sales $, items sold) and three quick-action buttons that deep-link to other tabs. The recent-transactions list widget exists but is currently commented out.

- **SalesScreen** (`screens/sales_screen.dart`) — Live camera QR scanner (MobileScanner) with an animated laser-line overlay. Scanned barcodes are matched against in-memory product state. If the barcode is unknown, an inline "quick add" dialog lets the user register the product on the spot. The cart supports quantity adjustments; checkout calls `SalesNotifier.checkoutProduct()` per cart item and shows a receipt dialog on success.

- **ProductListScreen** (`screens/product_list_screen.dart`) — Searchable list of all products (name, barcode, or ID). Products with quantity ≤ 5 are flagged with a red "Low Stock" badge. An add/edit dialog auto-generates a `PROD-XXXXXX` barcode for new products (overridable). Delete requires confirmation.

- **ProductDetailScreen** (`screens/product_detail_screen.dart`) — Pushed via `Navigator.push` from ProductListScreen. Renders the product's QR code using `QrImageView`. Print and Share buttons are simulated (no real printer/share integration yet).

- **SalesHistoryScreen** (`screens/sales_history_screen.dart`) — Displays all `SaleTransaction` records newest-first, with aggregate metrics (total revenue, quantity sold, transaction count). Includes a "Reset DB" FAB (destructive — deletes all products and transactions) for development use.

## State Management

All providers live in `lib/providers.dart`:

| Provider | Type | Description |
|---|---|---|
| `dbHelperProvider` | `Provider<DatabaseHelper>` | Singleton database helper |
| `productListProvider` | `StateNotifierProvider<ProductListNotifier, List<Product>>` | Full product list; exposes `addProduct`, `updateProduct`, `deleteProduct`, `loadProducts` |
| `searchQueryProvider` | `StateProvider<String>` | Current search text in ProductListScreen |
| `filteredProductsProvider` | `Provider<List<Product>>` | Derived: filters `productListProvider` by name, barcode, or ID |
| `salesProvider` | `StateNotifierProvider<SalesNotifier, List<SaleTransaction>>` | Transaction log; `checkoutProduct` atomically sells and reloads both products and transactions |
| `scannedBarcodeProvider` | `StateProvider<String?>` | Holds the most recently scanned barcode value |
| `scannedProductProvider` | `FutureProvider.autoDispose<Product?>` | Auto-resolves a product from a scanned barcode via the DB |

## How to Run

```bash
# Android
flutter run -d android

# Windows desktop
flutter run -d windows

# List available devices
flutter devices
```

`mobile_scanner` requires the camera permission. On Android, ensure `CAMERA` is declared in `AndroidManifest.xml` (added automatically by the package).

## Known Warnings / Notes

- **Unused learning artifacts:** `lib/models/greeting.dart` and `lib/services/greeting_service.dart` are from earlier Dart/Flutter practice exercises and are not wired into the main app. They can be deleted without affecting any functionality.
- **Commented-out recent sales list:** `DashboardScreen` has a `ListView.builder` for recent transactions that is commented out (lines 194–205). The `_buildTransactionItem` and `_buildEmptyState` helper methods are still present but unused.
- **Simulated print/share:** `ProductDetailScreen._simulatePrint()` and `_simulateShare()` show UI feedback only — no real thermal printer or system share-sheet integration exists yet.
- **No authentication:** The app has no user login; anyone with the device can access all features including the destructive "Reset DB" button.
