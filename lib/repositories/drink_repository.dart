import '../database/database_helper.dart';
import '../models/drink.dart';
import '../models/transaction.dart';

class DrinkRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get all drinks
  Future<List<Drink>> getAllDrinks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('Drinks');

    print("Drinks: $maps");
    return List.generate(maps.length, (i) {
      return Drink.fromMap(maps[i]);
    });
  }

  // Add a new drink
  Future<int> insertDrink(Drink drink) async {
    final db = await _dbHelper.database;
    return await db.insert('Drinks', drink.toMap());
  }

  // Update an existing drink
  Future<int> updateDrink(Drink drink) async {
    final db = await _dbHelper.database;
    return await db.update(
      'Drinks',
      drink.toMap(),
      where: 'id = ?',
      whereArgs: [drink.id],
    );
  }

  // Update drink stock
  Future<int> updateDrinkStock(int drinkId, int newStock) async {
    final db = await _dbHelper.database;
    return await db.update(
      'Drinks',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [drinkId],
    );
  }

  // Delete a drink
  Future<int> deleteDrink(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'Drinks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get a single drink by ID
  Future<Drink?> getDrink(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT d.*, m.name AS manufacturer_name
      FROM Drinks d
      JOIN Manufacturers m ON d.manufacturer = m.id
      WHERE d.id = ?
    ''', [id]);

    if (maps.isEmpty) return null;

    final drinkData = maps.first;

    return Drink(
      id: drinkData['id'],
      name: drinkData['name'],
      manufacturerId: drinkData['manufacturer'], // Still storing ID
      stock: drinkData['unit'],
      // manufacturerName: drinkData['manufacturer_name'], // New field
      // purchasePrice: drinkData['purchasePrice'],
      category: drinkData['category'],
      // unit: drinkData['unit'],
    );
  }


  // Add a new IN transaction
  Future<int> insertInTransaction(Transaction transaction) async {
    final db = await _dbHelper.database;
    int result = await db.insert('IN_Transactions', transaction.toMap());

    // Update stock after adding purchase
    await updateDrinkStock(transaction.drinkId, transaction.quantity);
    return result;
  }


  // Add a new OUT transaction
  Future<int> insertOutTransaction(Transaction transaction) async {
    final db = await _dbHelper.database;
    return await db.insert('OUT_Transactions', transaction.toMap());
  }

  // Get transactions by date range
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end, String transactionType) async {
    final db = await _dbHelper.database;
    final tableName =
        transactionType == 'in' ? 'IN_Transactions' : 'OUT_Transactions';

    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'transaction_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  // Get current stock for a drink
  Future<int> getCurrentStock(int drinkId) async {
    final db = await _dbHelper.database;

    // Calculate stock from IN and OUT transactions
    final inResult = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as total_in
      FROM IN_Transactions
      WHERE drink_id = ?
    ''', [drinkId]);

    final outResult = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as total_out
      FROM OUT_Transactions
      WHERE drink_id = ?
    ''', [drinkId]);

    final totalIn = inResult.first['total_in'] as int? ?? 0;
    final totalOut = outResult.first['total_out'] as int? ?? 0;

    return totalIn - totalOut;
  }

  // Add a payment
  Future<int> insertPayment(int manufacturerId, double amountPaid) async {
    final db = await _dbHelper.database;
    return await db.insert('Payments', {
      'manufacturer_id': manufacturerId,
      'amount_paid': amountPaid,
      'payment_date': DateTime.now().toIso8601String(),
    });
  }

  // Add a receivable
  Future<int> insertReceivable(int purchaserId, double amountDue) async {
    final db = await _dbHelper.database;
    return await db.insert('Receivables', {
      'purchaser_id': purchaserId,
      'amount_due': amountDue,
      'due_date': DateTime.now().toIso8601String(),
    });
  }
}
