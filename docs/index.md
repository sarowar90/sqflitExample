# SQFlite POS

A Flutter-based **offline Point-of-Sale (POS)** app (Dart package `sqflite_app`) that uses
the device camera to scan QR codes and process retail sales.

Store owners manage a product inventory, scan product QR codes at checkout to build a cart,
complete sales transactions, and review the full sales history — all stored **locally
on-device with SQLite**. There is no backend and no authentication.

!!! info "At a glance"
    - **Platform:** Flutter (primary target: Android — camera QR scanning)
    - **Storage:** local SQLite (`pos_database.db`) via the `sqflite` package
    - **State management:** [Riverpod](https://riverpod.dev)
    - **Scanning:** `mobile_scanner` (requires camera permission)
    - **Backend / auth:** none — fully offline

## What this app does

| Capability | Where |
|---|---|
| Manage a product inventory (add / edit / delete) | Inventory tab |
| Scan a product QR code to build a cart and check out | Scan POS tab |
| Decrement stock and record a sale **atomically** | `DatabaseHelper.sellProduct()` |
| Review full sales history and aggregates | Sales Log tab |
| See dashboard stats and quick actions | Dashboard tab |

## Documentation map

<div class="grid cards" markdown>

- :material-rocket-launch: **[Getting Started](getting-started.md)**
  Install dependencies, run on a device, and the essential commands.

- :material-sitemap: **[Architecture](architecture.md)**
  How the app is structured: data layer, models, state, and UI.

- :material-database: **[Database Schema](database-schema.md)**
  The two SQLite tables and the atomic-sale transaction.

- :material-state-machine: **[State Management](state-management.md)**
  The Riverpod providers that connect UI to the database.

- :material-cellphone: **[Screens](screens.md)**
  The four tabs and the pushed detail screen.

- :material-account-group: **[Contributing](contributing.md)**
  Dev setup, commit conventions, and how to add a screen or provider.

</div>

!!! warning "Camera required for scanning"
    `mobile_scanner` needs the camera permission and a real camera. QR scanning only works
    on a device with a camera — a physical Android phone is the realistic target. Desktop and
    web have no scannable camera flow.
