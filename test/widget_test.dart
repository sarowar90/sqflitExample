// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
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
  testWidgets('app opens on the dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(FakeDatabaseHelper())],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Smart Retail POS'), findsOneWidget);
    expect(find.text('Total Products'), findsOneWidget);
  });

  testWidgets('bottom navigation exposes all four tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(FakeDatabaseHelper())],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    // The dashboard's quick actions reuse these labels, so scope the search to
    // the navigation bar itself.
    Finder navLabel(String label) => find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    );

    expect(navLabel('Dashboard'), findsOneWidget);
    expect(navLabel('Scan POS'), findsOneWidget);
    expect(navLabel('Inventory'), findsOneWidget);
    expect(navLabel('Sales Log'), findsOneWidget);
  });

  testWidgets('tapping the Inventory tab shows the loaded products', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(FakeDatabaseHelper())],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('Laptop'), findsOneWidget);
  });
}
