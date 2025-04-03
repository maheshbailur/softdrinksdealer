import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/purchaser.dart';

class PurchaserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get all purchasers
  Future<List<Purchaser>> getAllPurchasers() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('Purchasers');
      return List.generate(maps.length, (i) {
        return Purchaser(
          id: maps[i]['id'],
          name: maps[i]['name'],
          contactInfo: maps[i]['contact_info'],
        );
      });
    } catch (e) {
      print('Error getting purchasers: $e');
      return [];
    }
  }

  // Insert a new purchaser
  Future<int> insertPurchaser(String name, String contactInfo) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert(
        'Purchasers',
        {
          'name': name,
          'contact_info': contactInfo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting purchaser: $e');
      return -1;
    }
  }

  // Update an existing purchaser
  Future<int> updatePurchaser(Purchaser purchaser) async {
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'Purchasers',
        purchaser.toMap(),
        where: 'id = ?',
        whereArgs: [purchaser.id],
      );
    } catch (e) {
      print('Error updating purchaser: $e');
      return -1;
    }
  }

  // Delete a purchaser
  Future<int> deletePurchaser(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'Purchasers',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting purchaser: $e');
      return -1;
    }
  }

  // Get a purchaser by ID
  Future<Purchaser?> getPurchaser(int id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'Purchasers',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return Purchaser(
        id: maps[0]['id'],
        name: maps[0]['name'],
        contactInfo: maps[0]['contact_info'],
      );
    } catch (e) {
      print('Error getting purchaser: $e');
      return null;
    }
  }
}