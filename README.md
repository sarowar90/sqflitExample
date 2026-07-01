# QR Code POS

An offline Flutter Point-of-Sale app that uses the device camera to scan product QR codes, manage inventory, and track sales history — all stored locally with SQLite.

## Features

- Live QR/barcode scanning for instant product lookup at checkout
- Cart management with quantity controls and stock validation
- Receipt dialog on successful sale
- Product inventory management (add, edit, delete, search)
- Auto-generated QR codes per product (viewable and printable)
- Sales history log with aggregate revenue metrics
- Dark mode UI with Material 3

## Getting Started

**Prerequisites:** Flutter SDK `^3.11.5`, a connected Android device or emulator (camera required for scanning).

```bash
# Install dependencies
flutter pub get

# Run on Android
flutter run -d android

# Run on Windows desktop
flutter run -d windows
```

## Developer Documentation

See [CLAUDE.md](CLAUDE.md) for full architecture documentation: project structure, database schema, state management providers, screen descriptions, and known caveats.
