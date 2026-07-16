import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_app/database_helper.dart';
import 'package:sqflite_app/models.dart';

/// Runs DatabaseHelper against a real SQLite database via the FFI factory,
/// which is what makes sqflite usable outside of a device/emulator.
void main() {
  final helper = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await helper.clearDatabase();
  });

  Future<Product> insertLaptop({int quantity = 10}) async {
    final id = await helper.insertProduct(
      Product(
        name: 'Laptop',
        price: 999.99,
        quantity: quantity,
        barcode: 'PROD-123456',
      ),
    );
    return (await helper.getProductById(id))!;
  }

  group('product CRUD', () {
    test('inserts a product and reads it back by id', () async {
      final laptop = await insertLaptop();

      expect(laptop.name, 'Laptop');
      expect(laptop.price, 999.99);
      expect(laptop.quantity, 10);
      expect(laptop.barcode, 'PROD-123456');
    });

    test('finds a product by its barcode', () async {
      await insertLaptop();

      final found = await helper.getProductByBarcode('PROD-123456');

      expect(found, isNotNull);
      expect(found!.name, 'Laptop');
    });

    test('returns null for a barcode that was never scanned in', () async {
      expect(await helper.getProductByBarcode('PROD-999999'), isNull);
    });

    test('rejects a duplicate barcode', () async {
      await insertLaptop();

      expect(
        () => helper.insertProduct(
          Product(
            name: 'Other laptop',
            price: 1.0,
            quantity: 1,
            barcode: 'PROD-123456',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('updates an existing product', () async {
      final laptop = await insertLaptop();

      await helper.updateProduct(laptop.copyWith(name: 'Gaming laptop'));

      expect((await helper.getProductById(laptop.id!))!.name, 'Gaming laptop');
    });

    test('deletes a product', () async {
      final laptop = await insertLaptop();

      await helper.deleteProduct(laptop.id!);

      expect(await helper.getProductById(laptop.id!), isNull);
      expect(await helper.getProducts(), isEmpty);
    });

    test('lists products newest first', () async {
      await insertLaptop();
      await helper.insertProduct(
        Product(
          name: 'Mouse',
          price: 25.5,
          quantity: 3,
          barcode: 'PROD-654321',
        ),
      );

      final products = await helper.getProducts();

      expect(products.map((p) => p.name), ['Mouse', 'Laptop']);
    });
  });

  group('sellProduct', () {
    test('decrements stock and logs the sale together', () async {
      final laptop = await insertLaptop(quantity: 10);

      final sold = await helper.sellProduct(laptop.id!, 2, 1999.98);

      expect(sold, isTrue);
      expect((await helper.getProductById(laptop.id!))!.quantity, 8);

      final transactions = await helper.getTransactions();
      expect(transactions, hasLength(1));
      expect(transactions.single.productId, laptop.id);
      expect(transactions.single.productName, 'Laptop');
      expect(transactions.single.quantity, 2);
      expect(transactions.single.totalPrice, 1999.98);
    });

    test('sells the entire remaining stock', () async {
      final laptop = await insertLaptop(quantity: 3);

      expect(await helper.sellProduct(laptop.id!, 3, 2999.97), isTrue);
      expect((await helper.getProductById(laptop.id!))!.quantity, 0);
    });

    test('refuses to oversell and leaves stock untouched', () async {
      final laptop = await insertLaptop(quantity: 1);

      final sold = await helper.sellProduct(laptop.id!, 2, 1999.98);

      expect(sold, isFalse);
      expect((await helper.getProductById(laptop.id!))!.quantity, 1);
      expect(await helper.getTransactions(), isEmpty);
    });

    test('refuses to sell a product that does not exist', () async {
      final sold = await helper.sellProduct(4242, 1, 10.0);

      expect(sold, isFalse);
      expect(await helper.getTransactions(), isEmpty);
    });

    test('snapshots the product name so renames do not rewrite history', () async {
      final laptop = await insertLaptop();
      await helper.sellProduct(laptop.id!, 1, 999.99);

      await helper.updateProduct(laptop.copyWith(name: 'Renamed laptop'));

      final transactions = await helper.getTransactions();
      expect(transactions.single.productName, 'Laptop');
    });

    test('keeps history after the product is deleted', () async {
      final laptop = await insertLaptop();
      await helper.sellProduct(laptop.id!, 1, 999.99);

      await helper.deleteProduct(laptop.id!);

      expect(await helper.getTransactions(), hasLength(1));
    });

    test('accumulates one row per sale, newest first', () async {
      final laptop = await insertLaptop(quantity: 10);

      await helper.sellProduct(laptop.id!, 1, 999.99);
      await helper.sellProduct(laptop.id!, 2, 1999.98);

      final transactions = await helper.getTransactions();
      expect(transactions.map((t) => t.quantity), [2, 1]);
      expect((await helper.getProductById(laptop.id!))!.quantity, 7);
    });
  });

  group('clearDatabase', () {
    test('removes both products and transactions', () async {
      final laptop = await insertLaptop();
      await helper.sellProduct(laptop.id!, 1, 999.99);

      await helper.clearDatabase();

      expect(await helper.getProducts(), isEmpty);
      expect(await helper.getTransactions(), isEmpty);
    });
  });
}
