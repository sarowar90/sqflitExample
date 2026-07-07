# State Management

State is managed with [Riverpod](https://riverpod.dev). All providers live in
`lib/providers.dart`, which is the hub connecting the UI to the database. Understand this file
before changing any screen behavior.

## Providers

| Provider | Type | Role |
|---|---|---|
| `dbHelperProvider` | `Provider<DatabaseHelper>` | The singleton DB helper |
| `productListProvider` | `StateNotifierProvider<ProductListNotifier, List<Product>>` | Full product list; `addProduct`, `updateProduct`, `deleteProduct`, `loadProducts` |
| `searchQueryProvider` | `StateProvider<String>` | Inventory search text |
| `filteredProductsProvider` | `Provider<List<Product>>` | Derived filter of `productListProvider` by name / barcode / ID |
| `salesProvider` | `StateNotifierProvider<SalesNotifier, List<SaleTransaction>>` | Transaction log; `checkoutProduct` atomically sells then reloads **both** products and transactions |
| `scannedBarcodeProvider` | `StateProvider<String?>` | Most recently scanned barcode |
| `scannedProductProvider` | `FutureProvider.autoDispose<Product?>` | Resolves a scanned barcode to a `Product` via the DB |

## The golden rule

!!! danger "Mutate through notifiers, never the DB directly from widgets"
    Any mutation that changes **stock** or **sales** must go through the notifiers
    (`ProductListNotifier`, `SalesNotifier`) — not through direct `DatabaseHelper` calls from
    widgets. Otherwise the in-memory Riverpod state will drift out of sync with the database.

## The checkout data-flow

After a sale, `SalesNotifier.checkoutProduct`:

1. Calls `DatabaseHelper.sellProduct()` — the atomic stock-decrement + sale-insert.
2. Reloads **product** state (so stock counts update everywhere).
3. Reloads **transaction** state (so the sales log updates).

```text
UI checkout ──► SalesNotifier.checkoutProduct
                     │
                     ├─► DatabaseHelper.sellProduct()   (atomic: stock-- + insert sale)
                     ├─► reload products    ──► productListProvider updates
                     └─► reload transactions ──► salesProvider updates
```

Reloading both keeps stock counts and the sales log consistent after every sale.

## Scanning flow

1. The scanner writes the latest value to `scannedBarcodeProvider`.
2. `scannedProductProvider` (autoDispose `FutureProvider`) resolves that barcode to a
   `Product` via the DB.
3. If it resolves to `null`, the barcode is unknown → the **Scan POS** screen offers an inline
   "quick add".
