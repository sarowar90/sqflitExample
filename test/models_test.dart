import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_app/models.dart';

void main() {
  group('Product', () {
    test('survives a toMap/fromMap round trip', () {
      final product = Product(
        id: 7,
        name: 'Laptop',
        price: 999.99,
        quantity: 10,
        barcode: 'PROD-123456',
      );

      final restored = Product.fromMap(product.toMap());

      expect(restored.id, 7);
      expect(restored.name, 'Laptop');
      expect(restored.price, 999.99);
      expect(restored.quantity, 10);
      expect(restored.barcode, 'PROD-123456');
    });

    test('omits a null id so SQLite can autoincrement it', () {
      final product = Product(
        name: 'Mouse',
        price: 25.5,
        quantity: 3,
        barcode: 'PROD-654321',
      );

      expect(product.toMap().containsKey('id'), isFalse);
    });

    test('reads an integer price column back as a double', () {
      final restored = Product.fromMap({
        'id': 1,
        'name': 'Cable',
        'price': 12,
        'quantity': 4,
        'barcode': 'PROD-000001',
      });

      expect(restored.price, 12.0);
    });

    test('copyWith replaces only the named fields', () {
      final product = Product(
        id: 1,
        name: 'Keyboard',
        price: 49.0,
        quantity: 8,
        barcode: 'PROD-111111',
      );

      final updated = product.copyWith(quantity: 5);

      expect(updated.quantity, 5);
      expect(updated.id, 1);
      expect(updated.name, 'Keyboard');
      expect(updated.price, 49.0);
      expect(updated.barcode, 'PROD-111111');
    });
  });

  group('SaleTransaction', () {
    test('survives a toMap/fromMap round trip', () {
      final timestamp = DateTime.parse('2026-07-17T10:30:00.000');
      final sale = SaleTransaction(
        id: 2,
        productId: 7,
        productName: 'Laptop',
        quantity: 2,
        totalPrice: 1999.98,
        timestamp: timestamp,
      );

      final restored = SaleTransaction.fromMap(sale.toMap());

      expect(restored.id, 2);
      expect(restored.productId, 7);
      expect(restored.productName, 'Laptop');
      expect(restored.quantity, 2);
      expect(restored.totalPrice, 1999.98);
      expect(restored.timestamp, timestamp);
    });

    test('stores the timestamp as an ISO 8601 string', () {
      final sale = SaleTransaction(
        productId: 1,
        productName: 'Mouse',
        quantity: 1,
        totalPrice: 25.5,
        timestamp: DateTime.parse('2026-07-17T10:30:00.000'),
      );

      expect(sale.toMap()['timestamp'], '2026-07-17T10:30:00.000');
    });
  });
}
