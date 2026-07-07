# Screens

`main.dart` renders `MainNavigationShell`, a `BottomNavigationBar` with **four fixed tabs**.
`product_detail_screen.dart` is not a tab — it is pushed via `Navigator.push`.

## Tabs

| Tab | Screen (`lib/screens/`) | Purpose |
|---|---|---|
| Dashboard | `dashboard_screen.dart` | Gradient stat cards + quick actions (recent-sales list is commented out) |
| Scan POS | `sales_screen.dart` | Live `MobileScanner` QR scanner → cart → checkout + receipt; unknown barcodes trigger an inline "quick add" |
| Inventory | `product_list_screen.dart` | Searchable products, add / edit / delete; low-stock badge at quantity ≤ 5; auto-generates `PROD-XXXXXX` barcodes |
| Sales Log | `sales_history_screen.dart` | All transactions newest-first + aggregates; destructive "Reset DB" FAB |

## Dashboard

`DashboardScreen` receives an `onTabChange(int)` callback from the shell so its quick-action
buttons can switch tabs programmatically.

!!! note "Dead code"
    The recent-transactions `ListView.builder` is commented out; `_buildTransactionItem` and
    `_buildEmptyState` remain but are currently unused.

## Scan POS

The live QR scanner requires a camera (Android is the realistic target). A scanned barcode is
resolved to a product; unknown barcodes trigger an inline **quick add** so you can create the
product on the spot before checkout. See [State Management](state-management.md#scanning-flow)
for the provider flow.

## Inventory

Searchable list backed by `filteredProductsProvider`. Adding a product auto-generates a
`PROD-XXXXXX` barcode. A **low-stock badge** appears at quantity ≤ 5.

## Sales Log

All transactions newest-first plus aggregate totals. The FAB triggers a destructive **Reset
DB** action.

!!! warning "Reset DB is destructive"
    Reset deletes all products and transactions with a confirmation dialog only — no auth, no
    backup. See [Database Schema → Resetting](database-schema.md#resetting-the-database).

## Product Detail (pushed)

`product_detail_screen.dart` is pushed via `Navigator.push` (not a tab) and renders a
product's QR via `QrImageView`.

!!! note "Print / Share are simulated"
    The Print and Share buttons on the detail screen are UI feedback only — they do not
    actually print or share.
