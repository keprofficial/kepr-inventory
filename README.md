# KEPR Inventory

The primary application is the Flutter + Supabase app under `flutter_app/`.
It follows the architecture and visual language of the sibling KEPR inspection
app in `C:\Users\purus\OneDrive\Documents\A\kepr`.

See `flutter_app/README.md` for Supabase table creation, configuration, run, and
Android release commands.

The web/Node implementation remains available as a prototype and API reference.

## Run

Requires Node.js 22.5 or newer (Node 24 recommended).

```powershell
node server.js
```

Open http://localhost:3000.

The SQLite database is created automatically at `data/inventory.db`. Back up that
file to back up the application. Schema changes live in `migrations/` and are
applied once in filename order.

For a PostgreSQL/Supabase deployment, apply the SQL files under
`supabase/migrations/`. The stock-level constraint uses `NULLS NOT DISTINCT` so
the warehouse's `NULL` apartment ID remains compatible with the application's
three-column `ON CONFLICT` upserts.

## Data integrity

- Product and apartment names are case-insensitively unique.
- Quantities and prices cannot be negative.
- Transfers use an immediate database transaction.
- A transfer either updates every line or rolls back completely.
- Warehouse stock cannot be overdrawn.
- Every transfer creates immutable movement records with a reference.
- SQLite foreign keys and WAL journaling are enabled.
