import 'package:flutter/material.dart';
import '../database/database_helper.dart';
// import '../models/drink.dart';
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';
import './drink_repository.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_alert_provider.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DrinkRepository _drinkRepository = DrinkRepository.instance;

  BuildContext? _context;
  void setContext(BuildContext context) {
    _context = context;
  }

  // ✅ Insert IN Transaction
  Future<int> insertInTransaction(InTransaction transaction) async {
    final db = await _dbHelper.database;

    // Insert the transaction into IN_Transactions table
    int result = await db.insert('IN_Transactions', transaction.toMap());

    if (result > 0) {
      // Update the stock of the drink
      await _drinkRepository.updateDrinkStock(transaction.drinkId, transaction.quantity);
      // Update out of stock count after transaction
      if (_context != null) {
        await Provider.of<InventoryAlertProvider>(_context!, listen: false)
            .updateOutOfStockCount();
      }
    }

    return result;
  }

  // ✅ Insert OUT Transaction
  Future<int> insertOutTransaction(OutTransaction transaction) async {
    final db = await _dbHelper.database;
    int result = await db.insert('OUT_Transactions', transaction.toMap());

    if (result > 0) {
      // Update the stock of the drink
      await _drinkRepository.updateDrinkStock(transaction.drinkId, -transaction.quantity);
      // Update out of stock count after transaction
      if (_context != null) {
        await Provider.of<InventoryAlertProvider>(_context!, listen: false)
            .updateOutOfStockCount();
      }
    }

    return result;
  }

  // ✅ Get IN Transactions
  Future<List<InTransaction>> getInTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'IN_Transactions',
      where: 'transaction_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return InTransaction.fromMap(maps[i]);
    });
  }

  // ✅ Get OUT Transactions
  Future<List<OutTransaction>> getOutTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'OUT_Transactions',
      where: 'transaction_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return OutTransaction.fromMap(maps[i]);
    });
  }

  Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    final db = await _dbHelper.database;

    // Get today's date in YYYY-MM-DD format
    final String today = DateTime.now().toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> transactions = await db.rawQuery('''
      SELECT 
        IN_T.id, 
        IN_T.drink_id, 
        D.name AS drink_name, 
        M.name AS manufacturer_name, 
        IN_T.quantity, 
        IN_T.price, 
        'IN' AS type, 
        IN_T.transaction_date
      FROM IN_Transactions AS IN_T
      JOIN Drinks AS D ON IN_T.drink_id = D.id
      LEFT JOIN Manufacturers AS M ON D.manufacturer_id = M.id
      WHERE DATE(IN_T.transaction_date) = DATE(?)

      UNION ALL

      SELECT 
        OUT_T.id, 
        OUT_T.drink_id, 
        D.name AS drink_name, 
        M.name AS manufacturer_name, 
        OUT_T.quantity, 
        OUT_T.price, 
        'OUT' AS type, 
        OUT_T.transaction_date
      FROM OUT_Transactions AS OUT_T
      JOIN Drinks AS D ON OUT_T.drink_id = D.id
      LEFT JOIN Manufacturers AS M ON D.manufacturer_id = M.id
      WHERE DATE(OUT_T.transaction_date) = DATE(?)

      ORDER BY transaction_date DESC
    ''', [today, today]);

    print("Today's Transactions: $transactions");

    return transactions;
  }

  Future<List<Map<String, dynamic>>> getTransactionsByPurchaser(int purchaserId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'OUT_Transactions',
      where: 'purchaser_id = ?',
      whereArgs: [purchaserId],
    );
  }

}