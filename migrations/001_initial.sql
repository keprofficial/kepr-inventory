PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
  unit TEXT NOT NULL CHECK (unit IN ('Pcs','Liters','Kg','Packets','Bottles')),
  unit_price REAL NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  reorder_level REAL NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS apartments (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
  contact TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stock_levels (
  location_type TEXT NOT NULL CHECK (location_type IN ('warehouse','apartment')),
  apartment_id INTEGER REFERENCES apartments(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  monthly_use REAL NOT NULL DEFAULT 0 CHECK (monthly_use >= 0),
  audited_at TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (location_type, apartment_id, product_id),
  CHECK (
    (location_type = 'warehouse' AND apartment_id IS NULL) OR
    (location_type = 'apartment' AND apartment_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS one_warehouse_level_per_product
  ON stock_levels(product_id) WHERE location_type = 'warehouse';

CREATE TABLE IF NOT EXISTS stock_movements (
  id INTEGER PRIMARY KEY,
  reference TEXT NOT NULL,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('receipt','transfer','adjustment')),
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  from_location TEXT,
  to_location TEXT,
  apartment_id INTEGER REFERENCES apartments(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK (quantity > 0),
  unit_price REAL NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  movement_date TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS stock_movements_reference_idx ON stock_movements(reference);
CREATE INDEX IF NOT EXISTS stock_movements_date_idx ON stock_movements(movement_date DESC);
