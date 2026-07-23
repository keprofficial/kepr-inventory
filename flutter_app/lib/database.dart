import 'dart:typed_data';

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

  Future<InventoryUser> currentUser() async {
    final userId = _db.auth.currentUser!.id;
    final row = await _db
        .from('inventory_users')
        .select()
        .eq('user_id', userId)
        .single();
    return InventoryUser.fromMap(Map<String, Object?>.from(row));
  }

  Future<List<StockRequest>> requests() async {
    final rows = await _db.from('inventory_request_summary_view').select();
    return rows
        .map((row) => StockRequest.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<String> createRequest(
    List<TransferLine> lines,
    String note,
  ) async {
    final result = await _db.rpc('inventory_create_request', params: {
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

  Future<String> checkRequest(
    int requestId, {
    required bool forward,
    String note = '',
  }) async {
    final result = await _db.rpc('inventory_check_request', params: {
      'p_request_id': requestId,
      'p_forward': forward,
      'p_note': note.trim(),
    });
    return result as String;
  }

  Future<String> financeReview(
    int requestId, {
    required bool approve,
    String note = '',
  }) async {
    final result = await _db.rpc('inventory_finance_review', params: {
      'p_request_id': requestId,
      'p_approve': approve,
      'p_note': note.trim(),
    });
    return result as String;
  }

  Future<String> uploadInvoiceAndFulfill({
    required int requestId,
    required String invoiceNumber,
    required String invoiceDate,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final safeName =
        filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').toLowerCase();
    final path =
        'requests/$requestId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _db.storage.from('inventory-invoices').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    try {
      final result = await _db.rpc('inventory_fulfill_request', params: {
        'p_request_id': requestId,
        'p_invoice_number': invoiceNumber.trim(),
        'p_invoice_date': invoiceDate,
        'p_storage_path': path,
        'p_original_filename': filename,
        'p_mime_type': mimeType,
        'p_size_bytes': bytes.length,
      });
      return result as String;
    } catch (_) {
      await _db.storage.from('inventory-invoices').remove([path]);
      rethrow;
    }
  }

  Future<String> issueApprovedStock(int requestId) async {
    final result = await _db.rpc(
      'inventory_issue_approved_stock',
      params: {'p_request_id': requestId},
    );
    return result as String;
  }

  Future<void> recordUsage({
    required int productId,
    required double quantity,
    String note = '',
  }) async {
    await _db.rpc('inventory_record_usage', params: {
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_usage_date': DateTime.now().toIso8601String().substring(0, 10),
      'p_note': note.trim(),
    });
  }

  Future<List<UsageSummary>> monthlyUsage() async {
    final rows = await _db.from('inventory_monthly_usage_view').select();
    return rows
        .map((row) => UsageSummary.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<List<WeeklyInsight>> weeklyInsights() async {
    final rows = await _db.from('inventory_weekly_insights_view').select();
    return rows
        .map((row) => WeeklyInsight.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<List<InvoiceRecord>> invoices({
    required DateTime month,
    DateTime? exactDate,
  }) async {
    dynamic query = _db.from('inventory_invoice_register_view').select();
    if (exactDate != null) {
      query = query.eq(
          'invoice_date', exactDate.toIso8601String().substring(0, 10));
    } else {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      query = query
          .gte('invoice_date', start.toIso8601String().substring(0, 10))
          .lt('invoice_date', end.toIso8601String().substring(0, 10));
    }
    final rows = await query;
    return (rows as List)
        .map((row) =>
            InvoiceRecord.fromMap(Map<String, Object?>.from(row as Map)))
        .toList();
  }

  Future<Uri> invoiceDownloadUrl(String storagePath) async {
    final url = await _db.storage
        .from('inventory-invoices')
        .createSignedUrl(storagePath, 300);
    return Uri.parse(url);
  }
}
