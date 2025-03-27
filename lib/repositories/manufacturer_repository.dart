import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/manufacturer.dart';

class ManufacturerRepository {
  Future<int> insertManufacturer(String name) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(
      'Manufacturers',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Manufacturer>> getAllManufacturers() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('Manufacturers');
    return maps.map((map) => Manufacturer.fromMap(map)).toList();
  }

  Future<void> deleteManufacturer(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Manufacturers', where: 'id = ?', whereArgs: [id]);
  }
}
