import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('drinks_inventory.db');
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
    await db.execute('''
      CREATE TABLE Manufacturers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        contact_info TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Purchasers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        contact_info TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Drinks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,   
        category TEXT NOT NULL,     
        stock INTEGER NOT NULL DEFAULT 0,
        manufacturer_id INTEGER,
        FOREIGN KEY (manufacturer_id) REFERENCES Manufacturers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IN_Transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drink_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,        
        transaction_date TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (drink_id) REFERENCES Drinks (id) ON DELETE CASCADE        
      )
    ''');

    await db.execute('''
      CREATE TABLE OUT_Transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drink_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        purchaser_id INTEGER NOT NULL,
        transaction_date TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (drink_id) REFERENCES Drinks (id) ON DELETE CASCADE,
        FOREIGN KEY (purchaser_id) REFERENCES Purchasers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manufacturer_id INTEGER NOT NULL,
        amount_paid REAL NOT NULL,
        payment_date TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (manufacturer_id) REFERENCES Manufacturers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Receivables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchaser_id INTEGER NOT NULL,
        amount_due REAL NOT NULL,
        due_date TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (purchaser_id) REFERENCES Purchasers (id) ON DELETE CASCADE
      )
    ''');
  }

  // Add method to clear tables (useful for testing)
  Future<void> clearTables() async {
    final db = await database;
    await db.delete('Receivables');
    await db.delete('Payments');
    await db.delete('OUT_Transactions');
    await db.delete('IN_Transactions');
    await db.delete('Drinks');
    // await db.delete('Purchasers');
    // await db.delete('Manufacturers');
  }

  // Add method to close database
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  // Add method to check if drink exists
  Future<bool> drinkExists(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'Drinks',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  // Add method to get database version
  Future<int> getVersion() async {
    final db = await database;
    return await db.getVersion();
  }

  // Add this new method
  Future<void> batchInsert(String table, List<Map<String, dynamic>> records) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          table, 
          record,
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
