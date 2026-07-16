## Tests — 2 finding(s)

### [Blocking] lib/database_helper.dart:166
**Untested:** `sellCart` does the same job as `sellProduct` — decrement stock and log a sale — so it
inherits `sellProduct`'s test bar: both the success path and the oversell refusal must be covered.
Neither is. The only `sellCart` reference in `test/` is
`FakeDatabaseHelper.sellCart` (`test/widget_test.dart:63`), a stub that unconditionally returns
`true` and is never itself asserted against — it exists only so the fake keeps implementing the
`DatabaseHelper` interface, not to exercise `sellCart`'s behaviour. `test/database_helper_test.dart`
has no `sellCart` group at all.
**Case to add:** In `test/database_helper_test.dart`, alongside the existing `group('sellProduct', ...)`
(lines 105-180): (1) a success case — seed two products, call `sellCart` with both, assert both
`quantity`s decremented and two rows land in `sales_transactions`; (2) the oversell/partial-failure
case that is the actual bug — seed product A with enough stock and product B without enough, call
`sellCart({A.id: qty, B.id: tooMany})`, assert it returns `false` **and** assert product A's stock
is unchanged and no sale for A was logged. That second case is the one that would fail against
today's implementation and pass only once `sellCart` is made atomic.
**Where:** `test/database_helper_test.dart`, new `group('sellCart', ...)`.

### [Should fix] lib/providers.dart:103
**Untested:** No test exercises `checkoutCart`. A test that checked out a cart and then asserted on
`productListProvider`'s state afterward would have caught that it never reloads the product list
(the `checkout-cart-state-drift` defect) — right now nothing would go red if that reload call were
removed, because nothing calls or asserts against `checkoutCart` at all.
**Case to add:** A provider/unit test that seeds a fake `DatabaseHelper`, calls
`salesProvider.notifier.checkoutCart(...)`, and asserts `productListProvider`'s state reflects the
post-sale quantities (not just that `salesProvider`'s transaction list updated).
**Where:** No existing test file covers `providers.dart` notifiers directly; nearest home is a new
provider test alongside `test/database_helper_test.dart`, or a `ProviderContainer`-based test if
one is introduced.

## Insufficient context
None. The bundle's `Tests` section already named the exact searches (`sellCart`, `checkoutCart`)
and their only hits; I did not need to re-grep.
