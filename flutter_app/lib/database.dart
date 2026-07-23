import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class InventoryDatabase {
  InventoryDatabase._();
  static final instance = InventoryDatabase._();
  Database? _database;

  Future<Database> get database async =>
      _database ??= await openDatabase(
        join(await getDatabasesPath(), 'kepr_inventory.db'),
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
      );

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(name)) > 0),
        unit TEXT NOT NULL CHECK(unit IN ('Pcs','Liters','Kg','Packets','Bottles')),
        unit_price REAL NOT NULL DEFAULT 0 CHECK(unit_price >= 0),
        reorder_level REAL NOT NULL DEFAULT 0 CHECK(reorder_level >= 0),
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('''
      CREATE TABLE apartments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(name)) > 0),
        contact TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('''
      CREATE TABLE stock_levels(
        location_type TEXT NOT NULL CHECK(location_type IN ('warehouse','apartment')),
        apartment_id INTEGER REFERENCES apartments(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        quantity REAL NOT NULL DEFAULT 0 CHECK(quantity >= 0),
        monthly_use REAL NOT NULL DEFAULT 0 CHECK(monthly_use >= 0),
        audited_at TEXT,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(location_type, apartment_id, product_id)
      )''');
    await db.execute(
      "CREATE UNIQUE INDEX warehouse_product_unique ON stock_levels(product_id) WHERE location_type='warehouse'",
    );
    await db.execute('''
      CREATE TABLE stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL,
        movement_type TEXT NOT NULL CHECK(movement_type IN ('receipt','transfer','adjustment')),
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        apartment_id INTEGER REFERENCES apartments(id) ON DELETE RESTRICT,
        quantity REAL NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL CHECK(unit_price >= 0),
        movement_date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute(
      'CREATE INDEX movement_reference_idx ON stock_movements(reference)',
    );
  }

  Future<List<Product>> products() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, COALESCE(s.quantity,0) quantity
      FROM products p LEFT JOIN stock_levels s
      ON s.product_id=p.id AND s.location_type='warehouse'
      ORDER BY p.name COLLATE NOCASE''');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> saveProduct({
    int? id,
    required String name,
    required String unit,
    required double quantity,
    required double unitPrice,
    required double reorderLevel,
    String notes = '',
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final productId = id ??
          await txn.insert('products', {
            'name': name.trim(),
            'unit': unit,
            'unit_price': unitPrice,
            'reorder_level': reorderLevel,
            'notes': notes.trim(),
          });
      if (id != null) {
        await txn.update(
          'products',
          {
            'name': name.trim(),
            'unit': unit,
            'unit_price': unitPrice,
            'reorder_level': reorderLevel,
            'notes': notes.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [id],
        );
        await txn.update(
          'stock_levels',
          {'quantity': quantity},
          where: "location_type='warehouse' AND product_id=?",
          whereArgs: [id],
        );
      } else {
        await txn.insert('stock_levels', {
          'location_type': 'warehouse',
          'product_id': productId,
          'quantity': quantity,
        });
      }
      return productId;
    });
  }

  Future<List<Apartment>> apartments() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*, COUNT(s.product_id) item_count,
        COALESCE(SUM(s.quantity*p.unit_price),0) stock_value
      FROM apartments a
      LEFT JOIN stock_levels s ON s.apartment_id=a.id AND s.location_type='apartment'
      LEFT JOIN products p ON p.id=s.product_id
      GROUP BY a.id ORDER BY a.name COLLATE NOCASE''');
    return rows.map(Apartment.fromMap).toList();
  }

  Future<int> addApartment(String name, String contact) async {
    final db = await database;
    return db.insert('apartments', {
      'name': name.trim(),
      'contact': contact.trim(),
    });
  }

  Future<List<ApartmentStock>> apartmentStock(int apartmentId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.product_id,p.name product_name,p.unit,p.unit_price,
        a.name apartment_name,
        s.quantity,s.monthly_use
      FROM stock_levels s JOIN products p ON p.id=s.product_id
      JOIN apartments a ON a.id=s.apartment_id
      WHERE s.location_type='apartment' AND s.apartment_id=?
      ORDER BY p.name COLLATE NOCASE''', [apartmentId]);
    return rows.map(ApartmentStock.fromMap).toList();
  }

  Future<void> updateUsage(
    int apartmentId,
    int productId,
    double monthlyUse,
  ) async {
    final db = await database;
    await db.update(
      'stock_levels',
      {
        'monthly_use': monthlyUse,
        'audited_at': DateTime.now().toIso8601String().substring(0, 10),
      },
      where:
          "location_type='apartment' AND apartment_id=? AND product_id=?",
      whereArgs: [apartmentId, productId],
    );
  }

  Future<String> transfer({
    required int apartmentId,
    required String date,
    required List<TransferLine> lines,
  }) async {
    if (lines.isEmpty) throw StateError('Add at least one item');
    final reference =
        'TR-${date.replaceAll('-', '')}-${Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final db = await database;
    await db.transaction((txn) async {
      for (final line in lines) {
        if (line.quantity <= 0) throw StateError('Quantity must be positive');
        final rows = await txn.rawQuery('''
          SELECT p.name,p.unit_price,s.quantity
          FROM products p JOIN stock_levels s ON s.product_id=p.id
          WHERE p.id=? AND s.location_type='warehouse' ''', [line.productId]);
        if (rows.isEmpty) throw StateError('Product not found');
        final product = rows.first;
        final available = (product['quantity'] as num).toDouble();
        if (available < line.quantity) {
          throw StateError(
            '${product['name']} has only $available available',
          );
        }
        await txn.rawUpdate('''
          UPDATE stock_levels SET quantity=quantity-?,updated_at=?
          WHERE location_type='warehouse' AND product_id=?''', [
          line.quantity,
          DateTime.now().toIso8601String(),
          line.productId,
        ]);
        await txn.rawInsert('''
          INSERT INTO stock_levels(location_type,apartment_id,product_id,quantity)
          VALUES('apartment',?,?,?)
          ON CONFLICT(location_type,apartment_id,product_id)
          DO UPDATE SET quantity=quantity+excluded.quantity,updated_at=CURRENT_TIMESTAMP
          ''', [apartmentId, line.productId, line.quantity]);
        await txn.insert('stock_movements', {
          'reference': reference,
          'movement_type': 'transfer',
          'product_id': line.productId,
          'apartment_id': apartmentId,
          'quantity': line.quantity,
          'unit_price': product['unit_price'],
          'movement_date': date,
        });
      }
    });
    return reference;
  }

  Future<List<TransferSummary>> transfers() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT m.reference,m.movement_date,a.name apartment,COUNT(*) line_count,
        SUM(m.quantity) total_quantity,SUM(m.quantity*m.unit_price) total_value
      FROM stock_movements m JOIN apartments a ON a.id=m.apartment_id
      WHERE m.movement_type='transfer'
      GROUP BY m.reference,m.movement_date,a.name
      ORDER BY MAX(m.id) DESC LIMIT 100''');
    return rows.map(TransferSummary.fromMap).toList();
  }
}
