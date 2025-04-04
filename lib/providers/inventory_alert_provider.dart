import 'package:flutter/foundation.dart';
import '../repositories/drink_repository.dart';

class InventoryAlertProvider with ChangeNotifier {
  final DrinkRepository _drinkRepository = DrinkRepository.instance;
  int _outOfStockCount = 0;
  
  int get outOfStockCount => _outOfStockCount;

  Future<void> updateOutOfStockCount() async {
    try {
      final drinks = await _drinkRepository.getAllDrinks();
      final newCount = drinks.where((drink) => drink.stock == 0).length;
      print('Current out of stock count: $_outOfStockCount'); // Debug print
      print('New out of stock count: $newCount'); // Debug print
      
      if (newCount != _outOfStockCount) {
        _outOfStockCount = newCount;
        print('Notifying listeners of new count: $_outOfStockCount'); // Debug print
        notifyListeners();
      }
    } catch (e) {
      print('Error updating out of stock count: $e');
    }
  }
}