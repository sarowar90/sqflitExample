import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        barcode TEXT NOT NULL UNIQUE
      )
    ''');

    // Sales transactions table
    await db.execute('''
      CREATE TABLE sales_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        total_price REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // --- Product CRUD ---

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final maps = await db.query('products', orderBy: 'id DESC');

    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Transaction Actions ---

  Future<bool> sellProduct(int productId, int quantitySold, double totalPrice) async {
    final db = await instance.database;
    try {
      return await db.transaction<bool>((txn) async {
        // 1. Get current quantity and name
        final List<Map<String, dynamic>> res = await txn.query(
          'products',
          columns: ['quantity', 'name'],
          where: 'id = ?',
          whereArgs: [productId],
        );

        if (res.isEmpty) return false;
        
        final int currentQty = res.first['quantity'] as int;
        final String name = res.first['name'] as String;

        if (currentQty < quantitySold) {
          return false; // Insufficient stock
        }

        // 2. Reduce the quantity
        final int newQty = currentQty - quantitySold;
        await txn.update(
          'products',
          {'quantity': newQty},
          where: 'id = ?',
          whereArgs: [productId],
        );

        // 3. Log the sales transaction
        await txn.insert('sales_transactions', {
          'product_id': productId,
          'product_name': name,
          'quantity': quantitySold,
          'total_price': totalPrice,
          'timestamp': DateTime.now().toIso8601String(),
        });

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  Future<List<SaleTransaction>> getTransactions() async {
    final db = await instance.database;
    final maps = await db.query('sales_transactions', orderBy: 'id DESC');

    return maps.map((map) => SaleTransaction.fromMap(map)).toList();
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('products');
    await db.delete('sales_transactions');
  }
}
