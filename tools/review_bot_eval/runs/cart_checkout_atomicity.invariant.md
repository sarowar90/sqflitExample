## Correctness — 2 finding(s)

### [Blocking] lib/database_helper.dart:166
**Breaks:** Sale atomicity — a stock decrement and its sale insert must happen inside one
`db.transaction`, with the stock read inside that same transaction and the `currentQty <
quantitySold` guard checked before any write.
**Failure:** `sellCart({1: 5, 2: 100})` where product 1 has 5 in stock and product 2 has only 3.
The loop processes product 1 first: `db.update` decrements its stock to 0 and `db.insert` logs its
sale — both committed immediately, not staged in a transaction. The loop then reads product 2,
finds `product.quantity (3) < entry.value (100)`, and returns `false` for the whole cart. The
caller sees the cart checkout as failed, but product 1's stock is already spent and its sale is
already in `sales_transactions` — a failed cart with real inventory and a real sale logged inside
it. Nothing rolls line 1 back.
A second, related failure: the method has no `try/catch`. `sellProduct` wraps its transaction in
`try { ... } catch (e) { return false; }` specifically so a thrown `DatabaseException` becomes a
clean `false`. `sellCart`'s `db.update`/`db.insert` calls are unguarded — if either throws on cart
line N>1, lines 1..N-1 have already been applied and the exception now propagates out of `sellCart`
uncaught, so a caller awaiting it sees an exception instead of the `false` every other path in this
class returns on failure.
**Reference:** `DatabaseHelper.sellProduct` (lib/database_helper.dart:117-161) does the read, the
guard, the decrement, and the insert inside one `db.transaction<bool>`, and wraps the whole call in
`try/catch`. `sellCart` performs the same job per cart line without either protection.
**Fix:** Wrap the loop body in a single `db.transaction` (re-reading and re-checking stock via
`txn`, not the outer `db`), and wrap the call in `try/catch` the way `sellProduct` does.

### [Should fix] lib/providers.dart:103
**Breaks:** State must not drift from the database — a mutation that changes stock must reload
`productListProvider`, and a mutation that changes sales must reload the transaction list. A cart
sale changes both.
**Failure:** A cart checkout via `checkoutCart` succeeds, decrementing stock for every line in the
cart. `checkoutCart` calls `loadTransactions()` but never calls
`_ref.read(productListProvider.notifier).loadProducts()`. The Sales Log updates immediately; the
Inventory screen keeps showing the pre-sale quantities until something else happens to trigger a
reload.
**Reference:** `SalesNotifier.checkoutProduct` (lib/providers.dart:91-100) reloads both
`loadTransactions()` and `productListProvider.notifier.loadProducts()` on success — the pattern
`checkoutCart` was evidently modeled on but only half-copied.
**Fix:** Add `await _ref.read(productListProvider.notifier).loadProducts();` after
`loadTransactions()` inside the `if (success)` block.

## Insufficient context
None. The bundle gave the full text of `sellCart`, `checkoutCart`, and both reference
implementations (`sellProduct`, `checkoutProduct`), plus confirmation that neither new method has a
caller yet — that latency doesn't change either finding above, per the rule to judge the code and
report the trigger as latent.
