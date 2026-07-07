# Architecture

Single-package Flutter app. All application code is under `lib/`; there are no feature
modules or layers beyond the flat structure below.

```text
┌─────────────────────────────────────────────────────────┐
│  UI  — main.dart, theme.dart, screens/                   │
│  BottomNavigationBar shell + four tabs + detail screen   │
└───────────────┬─────────────────────────────────────────┘
                │  reads state / calls notifier methods
┌───────────────▼─────────────────────────────────────────┐
│  State — providers.dart (Riverpod)                       │
│  Notifiers + derived providers — the UI ↔ DB hub         │
└───────────────┬─────────────────────────────────────────┘
                │  all mutations funnel through here
┌───────────────▼─────────────────────────────────────────┐
│  Data — database_helper.dart (DatabaseHelper singleton)  │
│  Owns all SQL against pos_database.db                    │
└───────────────┬─────────────────────────────────────────┘
                │  toMap / fromMap
┌───────────────▼─────────────────────────────────────────┐
│  Models — models.dart (Product, SaleTransaction)         │
└─────────────────────────────────────────────────────────┘
```

## Data layer — `lib/database_helper.dart`

`DatabaseHelper` is a **singleton** wrapping one SQLite database, `pos_database.db`, with two
tables (see [Database Schema](database-schema.md)). It owns all SQL.

The critical method is `sellProduct()`, which decrements product stock **and** inserts a
sales-transaction row inside a **single SQLite transaction** so a sale is atomic.

!!! danger "Never split the atomic sale"
    The stock decrement and the sales-transaction insert must stay inside the same SQLite
    transaction. Never edit these two writes to run independently — a crash between them would
    leave stock and sales history inconsistent.

## Models — `lib/models.dart`

`Product` and `SaleTransaction` are plain data classes with `toMap` / `fromMap` for SQLite
round-tripping.

!!! note "Point-in-time snapshot"
    `SaleTransaction` **denormalizes** `product_name` as a point-in-time snapshot, so renaming
    a product does **not** rewrite history.

## State — `lib/providers.dart`

This is the hub connecting UI to the database. Understand it before changing any screen
behavior — see the dedicated [State Management](state-management.md) page.

**Key data-flow rule:** after a sale, `SalesNotifier.checkoutProduct` reloads product *and*
transaction state so stock counts and the sales log stay consistent. Mutations that change
stock or sales must go through the notifiers, **not** direct `DatabaseHelper` calls from
widgets, or the in-memory state will drift from the DB.

## UI — `lib/main.dart`, `lib/theme.dart`, `lib/screens/`

- `main.dart` wraps the app in `ProviderScope` and renders `MainNavigationShell`, a
  `BottomNavigationBar` with four fixed tabs.
- `DashboardScreen` receives an `onTabChange(int)` callback so its quick-action buttons can
  switch tabs programmatically.
- `theme.dart` (`AppTheme`) defines the dark Material 3 palette, gradients, and
  Outfit / Share Tech Mono fonts via `google_fonts`.

See [Screens](screens.md) for a per-tab breakdown.
