# Contributing

## Dev setup

```bash
flutter pub get        # install dependencies
flutter doctor         # verify your toolchain
flutter run -d android # run on a device/emulator (primary target)
```

Before opening a change, run:

```bash
flutter analyze        # must be clean (flutter_lints)
flutter test           # see the note about the default test below
```

!!! warning "Replace the default test"
    `test/widget_test.dart` is still the default Flutter counter test and does not match this
    app — it will fail as-is. Replace it before relying on `flutter test`.

## Commit conventions

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <summary in imperative mood, lowercase, no period>
```

Common **types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
`chore`, `revert`. Useful **scopes** for this app: `dashboard`, `sales`, `inventory`, `db`,
`providers`, `theme`, `deps`, `docs`.

Examples:

```text
feat(inventory): add low-stock filter toggle
fix(db): keep stock decrement inside the sale transaction
docs(architecture): document the checkout data-flow
```

## How to add a new screen

1. Create `lib/screens/your_screen.dart`.
2. If it should be a tab, register it in `MainNavigationShell` in `main.dart` (the four tabs
   are fixed — adjust the `BottomNavigationBar` and the page list together).
3. If it is a detail/secondary screen, push it with `Navigator.push` instead (like
   `product_detail_screen.dart`).
4. Read state with `ref.watch(...)`; never call `DatabaseHelper` directly for stock/sales
   mutations — go through the notifiers (see below).

## How to add a new provider

1. Add the provider to `lib/providers.dart`.
2. For read-only derived data, prefer a plain `Provider` (like `filteredProductsProvider`).
3. For mutable state backed by the DB, add a `StateNotifier` and expose methods that:
   - call `DatabaseHelper`, then
   - reload the relevant state so the UI stays in sync.

!!! danger "Keep state and DB in sync"
    Any mutation that changes **stock** or **sales** must go through the notifiers and reload
    affected state. See [State Management](state-management.md#the-golden-rule).

## Editing these docs

The documentation is built with [MkDocs](https://www.mkdocs.org/) + the
[Material](https://squidfunk.github.io/mkdocs-material/) theme. Source lives in `docs/`.

```bash
pip install -r requirements-docs.txt   # one-time (needs Python 3)
mkdocs serve                           # live preview at http://127.0.0.1:8000
mkdocs build                           # build the static site into site/
```

Pushing changes under `docs/` (or `mkdocs.yml`) to `main` triggers the GitHub Actions workflow
that builds and deploys the site to GitHub Pages.

## Known gotchas

- **Leftover practice files:** `lib/models/greeting.dart` and `lib/services/greeting_service.dart`
  are unused; `lib/db/` and `lib/repositories/` are empty. Safe to delete.
- **Reset DB is unguarded:** confirmation dialog only — no auth, no backup.
- **Build warning:** `mobile_scanner` still applies the legacy Kotlin Gradle Plugin; builds
  today but future Flutter versions may reject it.
