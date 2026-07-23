import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Supabase-backed repository. The class name is retained so the UI remains
/// simple, but there is no device-local database.
class InventoryDatabase {
  InventoryDatabase._();
  static final instance = InventoryDatabase._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Product>> products() async {
    final rows = await _db.from('inventory_products_view').select();
    return rows
        .map((row) => Product.fromMap(Map<String, Object?>.from(row)))
        .toList();
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
    final result = await _db.rpc('inventory_save_product', params: {
      'p_id': id,
      'p_name': name.trim(),
      'p_unit': unit,
      'p_quantity': quantity,
      'p_unit_price': unitPrice,
      'p_reorder_level': reorderLevel,
      'p_notes': notes.trim(),
    });
    return (result as num).toInt();
  }

  Future<List<Apartment>> apartments() async {
    final rows = await _db.from('inventory_apartments_view').select();
    return rows
        .map((row) => Apartment.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<int> addApartment(String name, String contact) async {
    final row = await _db
        .from('inventory_apartments')
        .insert({'name': name.trim(), 'contact': contact.trim()})
        .select('id')
        .single();
    return (row['id'] as num).toInt();
  }

  Future<List<ApartmentStock>> apartmentStock(int apartmentId) async {
    final rows = await _db
        .from('inventory_apartment_stock_view')
        .select()
        .eq('apartment_id', apartmentId);
    return rows
        .map((row) => ApartmentStock.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<void> updateUsage(
    int apartmentId,
    int productId,
    double monthlyUse,
  ) async {
    await _db
        .from('inventory_stock_levels')
        .update({
          'monthly_use': monthlyUse,
          'audited_at': DateTime.now().toIso8601String().substring(0, 10),
        })
        .eq('location_type', 'apartment')
        .eq('apartment_id', apartmentId)
        .eq('product_id', productId);
  }

  Future<String> transfer({
    required int apartmentId,
    required String date,
    required List<TransferLine> lines,
  }) async {
    if (lines.isEmpty) throw StateError('Add at least one item');
    final result = await _db.rpc('inventory_transfer_stock', params: {
      'p_apartment_id': apartmentId,
      'p_movement_date': date,
      'p_lines': lines
          .map((line) => {
                'product_id': line.productId,
                'quantity': line.quantity,
              })
          .toList(),
    });
    return result as String;
  }

  Future<List<TransferSummary>> transfers() async {
    final rows = await _db.from('inventory_transfers_view').select().limit(100);
    return rows
        .map((row) => TransferSummary.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<String> receiveStock({
    required String date,
    required List<TransferLine> lines,
    String note = '',
  }) async {
    if (lines.isEmpty) throw StateError('Add at least one item');
    final result = await _db.rpc('inventory_receive_stock', params: {
      'p_movement_date': date,
      'p_lines': lines
          .map((line) => {
                'product_id': line.productId,
                'quantity': line.quantity,
              })
          .toList(),
      'p_note': note.trim(),
    });
    return result as String;
  }

  Future<List<StockMovement>> movements() async {
    final rows =
        await _db.from('inventory_movement_log_view').select().limit(200);
    return rows
        .map((row) => StockMovement.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }
}
