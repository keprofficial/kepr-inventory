# KEPR Inventory

A database-backed warehouse and apartment inventory application.

## Run

Requires Node.js 22.5 or newer (Node 24 recommended).

```powershell
node server.js
```

Open http://localhost:3000.

The SQLite database is created automatically at `data/inventory.db`. Back up that
file to back up the application. Schema changes live in `migrations/` and are
applied once in filename order.

## Data integrity

- Product and apartment names are case-insensitively unique.
- Quantities and prices cannot be negative.
- Transfers use an immediate database transaction.
- A transfer either updates every line or rolls back completely.
- Warehouse stock cannot be overdrawn.
- Every transfer creates immutable movement records with a reference.
- SQLite foreign keys and WAL journaling are enabled.
