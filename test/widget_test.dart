// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_app/main.dart';
import 'package:sqflite_app/models.dart';
import 'package:sqflite_app/database_helper.dart';
import 'package:sqflite_app/providers.dart';
import 'package:sqflite/sqflite.dart';

class FakeDatabaseHelper implements DatabaseHelper {
  @override
  Future<List<Product>> getProducts() async {
    return [
      Product(
        id: 1,
        name: 'Laptop',
        price: 999.99,
        quantity: 10,
        barcode: 'PROD-123456',
      ),
    ];
  }

  @override
  Future<List<SaleTransaction>> getTransactions() async => [];

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<void> clearDatabase() async {}

  @override
  Future<int> deleteProduct(int id) async => 1;

  @override
  Future<Product?> getProductByBarcode(String barcode) async => null;

  @override
  Future<Product?> getProductById(int id) async => null;

  @override
  Future<int> insertProduct(Product product) async => 1;

  @override
  Future<bool> sellProduct(
    int productId,
    int quantitySold,
    double totalPrice,
  ) async => true;

  @override
  Future<int> updateProduct(Product product) async => 1;
}

void main() {
  testWidgets('POS Scanner smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(FakeDatabaseHelper())],
        child: const MyApp(),
      ),
    );

    // Verify that the POS Scanner displays key elements on startup
    expect(find.text('QR Code Sales POS'), findsOneWidget);
    expect(find.text('Checkout Bill'), findsOneWidget);
  });
}
