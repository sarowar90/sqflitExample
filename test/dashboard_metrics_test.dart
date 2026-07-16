/// Characterization tests for the dashboard's four numbers.
///
/// Written against the metrics as DashboardScreen.build() computed them inline,
/// *before* they moved into dashboardMetricsProvider, so they pin the existing
/// behaviour rather than describe the new code. If the extraction changed an
/// answer, these go red — that is the whole point of writing them first.
///
/// The low-stock threshold in particular was a bare `<= 5` buried in a widget.
/// These tests fix its boundary in place so the constant that replaced it
/// cannot quietly drift.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_app/database_helper.dart';
import 'package:sqflite_app/models.dart';
import 'package:sqflite_app/providers.dart';

class _StubDatabaseHelper implements DatabaseHelper {
  _StubDatabaseHelper({this.products = const [], this.transactions = const []});

  final List<Product> products;
  final List<SaleTransaction> transactions;

  @override
  Future<List<Product>> getProducts() async => products;

  @override
  Future<List<SaleTransaction>> getTransactions() async => transactions;

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
  Future<bool> sellProduct(int productId, int quantitySold, double totalPrice) async => true;
  @override
  Future<int> updateProduct(Product product) async => 1;
}

Product _product({required int quantity, double price = 10.0, int id = 1}) => Product(
  id: id,
  name: 'P$id',
  price: price,
  quantity: quantity,
  barcode: 'PROD-00000$id',
);

SaleTransaction _sale({required int quantity, required double totalPrice, int id = 1}) => SaleTransaction(
  id: id,
  productId: 1,
  productName: 'P1',
  quantity: quantity,
  totalPrice: totalPrice,
  timestamp: DateTime.parse('2026-07-17T10:00:00.000'),
);

/// Builds the container and waits for both notifiers' constructor loads.
Future<DashboardMetrics> metricsFor({
  List<Product> products = const [],
  List<SaleTransaction> transactions = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      dbHelperProvider.overrideWithValue(
        _StubDatabaseHelper(products: products, transactions: transactions),
      ),
    ],
  );
  addTearDown(container.dispose);

  container.read(productListProvider);
  container.read(salesProvider);
  await Future<void>.delayed(Duration.zero);

  return container.read(dashboardMetricsProvider);
}

void main() {
  group('totalProducts', () {
    test('counts every product regardless of stock', () async {
      final metrics = await metricsFor(
        products: [_product(quantity: 0, id: 1), _product(quantity: 99, id: 2)],
      );
      expect(metrics.totalProducts, 2);
    });

    test('is zero with no products', () async {
      expect((await metricsFor()).totalProducts, 0);
    });
  });

  group('lowStockCount', () {
    test('counts products at or below the threshold', () async {
      final metrics = await metricsFor(
        products: [
          _product(quantity: 0, id: 1),
          _product(quantity: 5, id: 2),
          _product(quantity: 6, id: 3),
          _product(quantity: 100, id: 4),
        ],
      );
      expect(metrics.lowStockCount, 2);
    });

    test('five is low and six is not — the boundary, pinned', () async {
      expect((await metricsFor(products: [_product(quantity: 5)])).lowStockCount, 1);
      expect((await metricsFor(products: [_product(quantity: 6)])).lowStockCount, 0);
    });

    test('out of stock counts as low stock', () async {
      expect((await metricsFor(products: [_product(quantity: 0)])).lowStockCount, 1);
    });

    test('hasLowStock mirrors the count', () async {
      expect((await metricsFor(products: [_product(quantity: 5)])).hasLowStock, isTrue);
      expect((await metricsFor(products: [_product(quantity: 6)])).hasLowStock, isFalse);
    });
  });

  group('totalSalesValue', () {
    test('sums the total price of every transaction', () async {
      final metrics = await metricsFor(
        transactions: [
          _sale(quantity: 1, totalPrice: 10.50, id: 1),
          _sale(quantity: 2, totalPrice: 25.25, id: 2),
        ],
      );
      expect(metrics.totalSalesValue, 35.75);
    });

    test('is zero with no transactions', () async {
      expect((await metricsFor()).totalSalesValue, 0);
    });
  });

  group('totalItemsSold', () {
    test('sums quantities, not transaction count', () async {
      final metrics = await metricsFor(
        transactions: [
          _sale(quantity: 3, totalPrice: 30, id: 1),
          _sale(quantity: 2, totalPrice: 20, id: 2),
        ],
      );
      expect(metrics.totalItemsSold, 5);
    });

    test('is zero with no transactions', () async {
      expect((await metricsFor()).totalItemsSold, 0);
    });
  });

  test('products and sales are counted independently of each other', () async {
    final metrics = await metricsFor(
      products: [_product(quantity: 3, id: 1), _product(quantity: 50, id: 2)],
      transactions: [_sale(quantity: 4, totalPrice: 40)],
    );

    expect(metrics.totalProducts, 2);
    expect(metrics.lowStockCount, 1);
    expect(metrics.totalItemsSold, 4);
    expect(metrics.totalSalesValue, 40);
  });
}
