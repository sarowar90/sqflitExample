# Database Schema

All data lives in a single local SQLite database, **`pos_database.db`**, managed by the
`DatabaseHelper` singleton in `lib/database_helper.dart`. There are two tables.

## `products`

| Column | Type | Constraints |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `name` | TEXT | NOT NULL |
| `price` | REAL | NOT NULL |
| `quantity` | INTEGER | NOT NULL |
| `barcode` | TEXT | NOT NULL, UNIQUE |

## `sales_transactions`

| Column | Type | Constraints |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `product_id` | INTEGER | NOT NULL |
| `product_name` | TEXT | NOT NULL — denormalized snapshot |
| `quantity` | INTEGER | NOT NULL |
| `total_price` | REAL | NOT NULL |
| `timestamp` | TEXT | NOT NULL — ISO 8601 |

!!! note "Why `product_name` is duplicated"
    `sales_transactions.product_name` is a **point-in-time snapshot** of the product's name at
    the moment of sale. Renaming or deleting a product later does not rewrite past sales, so
    the history stays truthful.

## The atomic sale

`DatabaseHelper.sellProduct()` performs two writes inside **one** SQLite transaction:

1. Decrement `products.quantity` for the sold product.
2. Insert a new row into `sales_transactions`.

```text
BEGIN TRANSACTION
  UPDATE products SET quantity = quantity - N WHERE id = ?
  INSERT INTO sales_transactions (...) VALUES (...)
COMMIT
```

!!! danger "Keep it atomic"
    These two writes must always commit together. If you ever change `sellProduct()`, keep
    both statements in the same transaction so a sale can never half-apply.

## Resetting the database

The **Sales Log** tab has a destructive "Reset DB" action that deletes **all** products and
transactions.

!!! warning "Reset DB is unguarded"
    Reset is protected by a confirmation dialog only — there is no auth and no backup. Once
    confirmed, all inventory and sales history are gone.
