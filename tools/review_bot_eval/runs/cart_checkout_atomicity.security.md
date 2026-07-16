## Security — no findings

`sellCart` writes through `db.update`/`db.insert` with structured column maps and `whereArgs:
[entry.key]` — no string-built `where` clause, no interpolated SQL. `checkoutCart` and
`FakeDatabaseHelper.sellCart` add no I/O beyond the existing `DatabaseHelper`/`sqflite` calls: no
new network call, no new destructive/delete path, no `AndroidManifest.xml` change, and no new
handling of scanned-barcode text. Nothing in this diff falls inside this app's threat model.

## Insufficient context
None.
