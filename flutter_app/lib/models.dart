class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.reorderLevel,
    this.notes = '',
  });

  final int id;
  final String name;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double reorderLevel;
  final String notes;

  bool get isLow => quantity <= reorderLevel;
  double get value => quantity * unitPrice;

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int,
        name: map['name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        reorderLevel: (map['reorder_level'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String? ?? '',
      );
}

class Apartment {
  const Apartment({
    required this.id,
    required this.name,
    this.contact = '',
    this.itemCount = 0,
    this.stockValue = 0,
  });

  final int id;
  final String name;
  final String contact;
  final int itemCount;
  final double stockValue;

  factory Apartment.fromMap(Map<String, Object?> map) => Apartment(
        id: map['id'] as int,
        name: map['name'] as String,
        contact: map['contact'] as String? ?? '',
        itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
        stockValue: (map['stock_value'] as num?)?.toDouble() ?? 0,
      );
}

class ApartmentStock {
  const ApartmentStock({
    required this.apartmentName,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.monthlyUse,
    required this.unitPrice,
  });

  final String apartmentName;
  final int productId;
  final String productName;
  final String unit;
  final double quantity;
  final double monthlyUse;
  final double unitPrice;
  double? get daysRemaining =>
      monthlyUse > 0 ? quantity / (monthlyUse / 30) : null;
  double get need15 =>
      ((monthlyUse / 2) - quantity).clamp(0, double.infinity).toDouble();
  double get need30 =>
      (monthlyUse - quantity).clamp(0, double.infinity).toDouble();

  factory ApartmentStock.fromMap(Map<String, Object?> map) => ApartmentStock(
        apartmentName: map['apartment_name'] as String,
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        monthlyUse: (map['monthly_use'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
      );
}

class TransferSummary {
  const TransferSummary({
    required this.reference,
    required this.date,
    required this.apartment,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalValue,
  });
  final String reference;
  final String date;
  final String apartment;
  final int lineCount;
  final double totalQuantity;
  final double totalValue;

  factory TransferSummary.fromMap(Map<String, Object?> map) => TransferSummary(
        reference: map['reference'] as String,
        date: map['movement_date'] as String,
        apartment: map['apartment'] as String,
        lineCount: (map['line_count'] as num).toInt(),
        totalQuantity: (map['total_quantity'] as num).toDouble(),
        totalValue: (map['total_value'] as num).toDouble(),
      );
}

class TransferLine {
  TransferLine({required this.productId, required this.quantity});
  int productId;
  double quantity;
}

class StockMovement {
  const StockMovement({
    required this.reference,
    required this.type,
    required this.date,
    required this.destination,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalValue,
  });

  final String reference;
  final String type;
  final String date;
  final String destination;
  final int lineCount;
  final double totalQuantity;
  final double totalValue;

  bool get isReceipt => type == 'receipt';

  factory StockMovement.fromMap(Map<String, Object?> map) => StockMovement(
        reference: map['reference'] as String,
        type: map['movement_type'] as String,
        date: map['movement_date'] as String,
        destination: map['destination'] as String? ?? 'Warehouse',
        lineCount: (map['line_count'] as num).toInt(),
        totalQuantity: (map['total_quantity'] as num).toDouble(),
        totalValue: (map['total_value'] as num).toDouble(),
      );
}
