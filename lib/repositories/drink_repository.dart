import '../database/database_helper.dart';
import '../models/drink.dart';
// import '../models/transaction.dart';

class DrinkRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get all drinks
  Future<List<Drink>> getAllDrinks() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT d.*, m.name AS manufacturer_name 
      FROM Drinks d
      LEFT JOIN Manufacturers m ON d.manufacturer_id = m.id
    ''');

    return List.generate(maps.length, (i) => Drink.fromMap(maps[i]));
  }

  // Add a new drink
  Future<int> insertDrink(Drink drink) async {
    final db = await _dbHelper.database;
    // Remove manufacturer_name from the insertion
    final drinkMap = {
      'name': drink.name,
      'category': drink.category,
      'stock': drink.stock,
      'manufacturer_id': drink.manufacturerId,
    };
    return await db.insert('Drinks', drinkMap);
  }

  // Update an existing drink
  Future<int> updateDrink(Drink drink) async {
    final db = await _dbHelper.database;
    final drinkMap = {
      'name': drink.name,
      'category': drink.category,
      'stock': drink.stock,
      'manufacturer_id': drink.manufacturerId,
    };
    return await db.update(
      'Drinks',
      drinkMap,
      where: 'id = ?',
      whereArgs: [drink.id],
    );
  }

  // Update drink stock
  Future<int> updateDrinkStock(int drinkId, int additionalStock) async {
    final db = await _dbHelper.database;

    // Fetch the existing drink details
    Drink? drink = await getDrink(drinkId);
    
    if (drink == null) {
      print("Drink not found with ID: $drinkId");
      return 0; // Return 0 if drink doesn't exist
    }

    int newStock = drink.stock + additionalStock; // Add new stock

    // Update the stock in the database
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
      LEFT JOIN Manufacturers m ON d.manufacturer_id = m.id
      WHERE d.id = ?
    ''', [id]);

    if (maps.isEmpty) return null;

    final drinkData = maps.first;

    return Drink(
      id: drinkData['id'],
      name: drinkData['name'],
      manufacturerId: drinkData['manufacturer_id'], // Fixed column name
      stock: drinkData['stock'], // Fixed column name
      category: drinkData['category'],
      //manufacturerName: drinkData['manufacturer_name'], // If needed, add this field in your Drink model
    );
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
