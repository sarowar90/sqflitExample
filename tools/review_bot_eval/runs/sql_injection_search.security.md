## Security — 1 finding

### [Blocking] lib/database_helper.dart — `searchProducts`
**Risk:** SQL injection. The `query` string is interpolated directly into the SQL text (`"... LIKE '%$query%' ..."`) instead of being passed via `whereArgs`, so a query containing `'` or SQL syntax breaks out of the `LIKE` clause and runs attacker-chosen SQL against `pos_database.db`.
**Input:** the `query` parameter of `searchProducts(String query)`, sourced from `searchQueryProvider`, which `product_list_screen.dart`'s free-text inventory search box writes.
**Reachable via:** Inventory search box -> `searchQueryProvider` -> `dbSearchResultsProvider` (watches `searchQueryProvider`) -> `DatabaseHelper.searchProducts(query)` -> `db.rawQuery(...)`. Every other method in `database_helper.dart` uses `where:`/`whereArgs` for exactly this reason; this is the only one that doesn't.
**Fix:** `db.rawQuery('SELECT * FROM products WHERE name LIKE ? OR barcode LIKE ? ORDER BY id DESC', ['%$query%', '%$query%'])`.

## Insufficient context
Per the bundle's own Gaps note, `dbSearchResultsProvider` is not watched by any widget in `lib/screens/`, so I can't confirm from this diff alone whether the vulnerable path currently executes at runtime from a live UI trigger. That doesn't change the finding: the interpolated, unparameterized `rawQuery` is new code introduced by this PR and is injectable the moment anything feeds it user- or scan-supplied text.

No other findings — no new network call, no new destructive path, and no new `AndroidManifest.xml` permission or dependency in this diff.
