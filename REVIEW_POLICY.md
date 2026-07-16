# Review Policy

What the PR review bot checks, and — just as importantly — what it stays quiet about.

This file is the bot's rubric — what to check. [`REVIEW_BOT.md`](REVIEW_BOT.md) covers who checks
it. A review is **useful** when every comment would change what a maintainer does. A review is **noisy** when it restates the diff, repeats the linter, or flags
things that were already true before the PR. Noise is the default failure mode: a bot that
comments on everything gets muted, and then it catches nothing.

## Guiding rules

1. **Only comment on lines the PR changed.** Pre-existing problems are not this PR's job.
   The one exception is when changed code *depends on* something broken nearby — then say so
   explicitly and point at the dependency.
2. **Never report what a tool already reports.** `flutter analyze` and `dart format` run in CI.
   Formatting, unused imports, missing `const`, and lint violations are their territory.
3. **Every comment needs a failure.** State the concrete input or sequence that produces the
   wrong result. If you cannot describe how it breaks, it is a preference, not a finding.
4. **One comment per problem.** Not one per occurrence.
5. **Silence is a valid review.** "No blocking findings" on a clean PR is the correct output.

## Severity

| Level | Meaning | Examples |
|---|---|---|
| **Blocking** | Corrupts data, loses money, or breaks a documented invariant | Sale recorded without stock decrement; SQL built by string interpolation |
| **Should fix** | Real bug, but narrow blast radius | Stale UI after a mutation; missing test for a new DB method |
| **Consider** | Genuine improvement, author may decline | Duplicated query logic that belongs in `DatabaseHelper` |

Never open with praise. Lead with the most severe finding.

---

## 1. Correctness

This is a POS app. Money and stock counts are the things that must not go wrong.

### Sale atomicity — the invariant that matters most

`DatabaseHelper.sellProduct()` decrements stock **and** inserts the `sales_transactions` row
inside one `db.transaction`. **Blocking** if a diff:

- moves either write outside the transaction, or splits them into separate calls
- reads stock outside the transaction and passes the value in (read must happen inside, or two
  concurrent sales can both pass the check and oversell)
- drops the `currentQty < quantitySold` guard, or checks it after the decrement
- lets an exception escape such that a caller treats a failed sale as successful

### State must not drift from the database

`SalesNotifier.checkoutProduct` reloads **both** transactions and the product list after a sale.
`docs/state-management.md` calls this the golden rule.

- **Blocking:** a widget calls `DatabaseHelper` directly for a stock or sales mutation instead of
  going through a notifier. The DB changes, in-memory state does not, and the UI shows stale stock
  until the next reload.
- **Should fix:** a new notifier method mutates the DB but reloads only its own state, or reloads
  nothing.
- **Should fix:** a mutation that changes stock reloads transactions but not `productListProvider`
  (or vice versa).

### History is a snapshot, not a join

`sales_transactions.product_name` is denormalized on purpose: renaming a product must not rewrite
past receipts, and deleting a product must not erase its sales.

- **Blocking:** replacing `product_name` with a lookup/join against `products`, or adding a foreign
  key with `ON DELETE CASCADE` to `product_id`.
- **Should fix:** new denormalized columns that are refreshed from `products` after the fact.

### Schema and mapping

- `barcode` is `NOT NULL UNIQUE`. Inserts must handle the constraint failing —
  `ProductListNotifier.addProduct` catches it and returns `false`. **Should fix** a new insert path
  that lets the `DatabaseException` reach the UI as a crash.
- `price` is `REAL` but SQLite may hand back an `int`. `fromMap` uses `(map['price'] as num).toDouble()`.
  **Should fix:** a new numeric column read with a bare `as double`.
- `Product.toMap()` omits a null `id` so AUTOINCREMENT works. **Should fix:** a change that always
  writes `id`.
- Any change to `_createDB` without a matching `version` bump and migration path is **blocking** —
  existing installs will not pick up the new schema.

### Riverpod

- **Should fix:** `ref.watch` in a callback (`onPressed`, `onTap`), or `ref.read` for something the
  widget must rebuild on.
- **Consider:** dropping `.autoDispose` from `scannedProductProvider` — it keeps a stale scan alive
  across visits to the scanner.

---

## 2. Tests

The suite lives in `test/`. `flutter test` must pass. Coverage percentage is not a target.

- **Should fix:** a new `DatabaseHelper` method with no test in `test/database_helper_test.dart`.
- **Blocking:** a change to `sellProduct` without tests for both the success path *and* the
  oversell refusal. This method is the one place a bug costs real inventory.
- **Should fix:** a bug fix with no test that fails without it.
- **Should fix:** a widget test that reaches real SQLite instead of overriding `dbHelperProvider`
  with a fake. Database tests need `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`;
  widget tests should not need a database at all.
- **Consider:** tests asserting on `find.text` for a string that also appears elsewhere on screen —
  scope to an ancestor instead (the nav labels and dashboard quick actions collide today).
- Do **not** ask for tests covering the camera, `MobileScanner`, or `QrImageView` rendering. They
  need a device and are out of scope.

---

## 3. Security and data safety

The threat model is small and worth stating plainly: the app is offline, on-device, single-user,
with no auth and no backend. Most web-app security findings do not apply here. What does:

- **Blocking:** SQL assembled by string interpolation. Every query uses `whereArgs` today; a
  `where: 'name = $name'` is an injection via product name or scanned barcode.
- **Blocking:** any new network call. This app has no backend, and sales data leaving the device is
  a privacy change, not a feature. Flag it even if the endpoint looks harmless (analytics, crash
  reporting, telemetry).
- **Blocking:** a new destructive path (mass delete, overwrite, reset) without a confirmation
  dialog. `clearDatabase()` is reachable from the Sales Log "Reset DB" FAB behind confirmation
  only — no auth, no backup. Match that bar at minimum; do not lower it.
- **Should fix:** new permissions in `AndroidManifest.xml` beyond `CAMERA`, or a dependency that
  pulls one in.
- **Should fix:** scanned barcode text rendered or logged without bounds — a QR code carries
  attacker-controlled text.
- Do **not** flag: absence of auth, absence of encryption at rest, or the unguarded reset FAB
  itself. Those are known, accepted, and documented.

---

## 4. Style

Only what the linter cannot see.

- **Should fix:** hardcoded colors, gradients, or font families. `theme.dart` (`AppTheme`) owns the
  palette; fonts come from `google_fonts` (Outfit / Share Tech Mono).
- **Consider:** SQL written outside `DatabaseHelper`. It owns every query.
- **Consider:** a new tab screen not placed in `lib/screens/`, or registered in the page list
  without a matching `BottomNavigationBar` item (they must move together).
- **Should fix:** `print()` in shipped code.
- **Consider:** a comment explaining *what* the next line does. Comments earn their place by
  recording a constraint the code cannot show.
- Commit messages follow Conventional Commits (`docs/contributing.md`). Flag a malformed
  **PR title**, since that becomes the squash-merge subject. Do not audit individual commits inside
  the PR.

---

## 5. Known noise — do not report

These are already known, documented, and deliberately unfixed. Flagging them is how the bot loses
its audience:

- Dead code in `dashboard_screen.dart` (`_buildTransactionItem`, `_buildEmptyState`, the commented
  out recent-sales `ListView.builder`) — `flutter analyze` already warns.
- Leftover practice files: `lib/models/greeting.dart`, `lib/services/greeting_service.dart`, and
  the empty `lib/db/` and `lib/repositories/`.
- `mobile_scanner` applying the legacy Kotlin Gradle Plugin.
- Print/Share buttons in `product_detail_screen.dart` being simulated.
- The `site/` build output, if it ever appears in a diff — say "gitignore this" once, not per file.
- Missing null-safety, missing i18n, missing dark/light toggle. The app is dark-mode only by design.

## Output format

```
### Verdict
<Blocking | Should fix | Consider | No blocking findings> — one sentence.

### Findings
1. **[Severity]** `file.dart:42` — what breaks, and the input that breaks it.
   Suggested fix, if it is short.
```

If there are no findings, print the verdict line alone. Do not pad.
