class Product {
  final int? id;
  final String name;
  final double price;
  final int quantity;
  final String barcode;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.barcode,
  });

  Product copyWith({
    int? id,
    String? name,
    double? price,
    int? quantity,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'barcode': barcode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      barcode: map['barcode'] as String,
    );
  }
}

class SaleTransaction {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double totalPrice;
  final DateTime timestamp;

  SaleTransaction({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'total_price': totalPrice,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      totalPrice: (map['total_price'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
