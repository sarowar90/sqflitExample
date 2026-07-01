import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_helper.dart';
import 'models.dart';

// --- Database instance provider ---
final dbHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

// --- Product list state management ---
class ProductListNotifier extends StateNotifier<List<Product>> {
  final DatabaseHelper _dbHelper;

  ProductListNotifier(this._dbHelper) : super([]) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    final products = await _dbHelper.getProducts();
    state = products;
  }

  Future<bool> addProduct(String name, double price, int quantity, String barcode) async {
    final newProduct = Product(
      name: name,
      price: price,
      quantity: quantity,
      barcode: barcode,
    );
    try {
      await _dbHelper.insertProduct(newProduct);
      await loadProducts();
      return true;
    } catch (e) {
      return false; // Barcode duplication or other SQLite constraint
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      await _dbHelper.updateProduct(product);
      await loadProducts();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteProduct(int id) async {
    await _dbHelper.deleteProduct(id);
    await loadProducts();
  }
}

final productListProvider = StateNotifierProvider<ProductListNotifier, List<Product>>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  return ProductListNotifier(dbHelper);
});

// --- Search and Filtering ---
final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productListProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  if (searchQuery.isEmpty) {
    return products;
  }

  return products.where((product) {
    final nameMatches = product.name.toLowerCase().contains(searchQuery);
    final barcodeMatches = product.barcode.toLowerCase().contains(searchQuery);
    final idMatches = product.id?.toString() == searchQuery;
    return nameMatches || barcodeMatches || idMatches;
  }).toList();
});

// --- Transaction list state management ---
class SalesNotifier extends StateNotifier<List<SaleTransaction>> {
  final DatabaseHelper _dbHelper;
  final Ref _ref;

  SalesNotifier(this._dbHelper, this._ref) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final transactions = await _dbHelper.getTransactions();
    state = transactions;
  }

  Future<bool> checkoutProduct(int productId, int quantitySold, double totalPrice) async {
    final success = await _dbHelper.sellProduct(productId, quantitySold, totalPrice);
    if (success) {
      // Reload transactions log
      await loadTransactions();
      // Reload products list to reflect stock deduction in the UI
      await _ref.read(productListProvider.notifier).loadProducts();
    }
    return success;
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, List<SaleTransaction>>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  return SalesNotifier(dbHelper, ref);
});

// --- POS / QR Scanner State ---
final scannedBarcodeProvider = StateProvider<String?>((ref) => null);

final scannedProductProvider = FutureProvider.autoDispose<Product?>((ref) async {
  final barcode = ref.watch(scannedBarcodeProvider);
  if (barcode == null || barcode.isEmpty) return null;
  
  final dbHelper = ref.watch(dbHelperProvider);
  return await dbHelper.getProductByBarcode(barcode);
});
