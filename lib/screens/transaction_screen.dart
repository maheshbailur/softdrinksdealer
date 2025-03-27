import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/drink.dart';
import '../models/purchaser.dart';
import '../database/database_helper.dart';
import '../repositories/drink_repository.dart';

class TransactionScreen extends StatefulWidget {
  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<Transaction> transactions = [];
  List<Drink> drinks = [];
  List<Purchaser> purchasers = [];
  final _formKey = GlobalKey<FormState>();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  Drink? _selectedDrink;
  Purchaser? _selectedPurchaser; // For OUT transactions

  @override
  void initState() {
    super.initState();
    _loadDrinks();
    _loadPurchasers();
  }

  Future<void> _loadDrinks() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('Drinks');
    setState(() {
      drinks = maps.map((map) => Drink.fromMap(map)).toList();
    });
  }

  Future<void> _loadPurchasers() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('Purchasers');
    setState(() {
      purchasers = maps.map((map) => Purchaser.fromMap(map)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final drink = drinks.firstWhere(
                  (d) => d.id == transaction.drinkId,
                  orElse: () => Drink(id: 0, name: 'Unknown', category: 'select', stock: 0, manufacturerId: null),
                );
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('${transaction.transactionType.toUpperCase()} - ${drink.name}'),
                    subtitle: Text('Unit: ${transaction.quantity}, Price: ${transaction.price}'),
                    trailing: Text(transaction.transactionDate.toString().split(' ')[0]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _showTransactionDialog('in'),
            label: Text('IN'),
            icon: Icon(Icons.add),
          ),
          SizedBox(width: 10),
          FloatingActionButton.extended(
            onPressed: () => _showTransactionDialog('out'),
            label: Text('OUT'),
            icon: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(String transactionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transactionType.toUpperCase() + ' Transaction'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Drink>(
                  value: _selectedDrink,
                  decoration: InputDecoration(labelText: 'Product'),
                  items: drinks.map((Drink drink) {
                    return DropdownMenuItem<Drink>(
                      value: drink,
                      child: Text(drink.name),
                    );
                  }).toList(),
                  onChanged: (Drink? newValue) {
                    setState(() {
                      _selectedDrink = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a product' : null,
                ),
                if (transactionType == 'out')
                  DropdownButtonFormField<Purchaser>(
                    value: _selectedPurchaser,
                    decoration: InputDecoration(labelText: 'Purchaser'),
                    items: purchasers.map((Purchaser purchaser) {
                      return DropdownMenuItem<Purchaser>(
                        value: purchaser,
                        child: Text(purchaser.name),
                      );
                    }).toList(),
                    onChanged: (Purchaser? newValue) {
                      setState(() {
                        _selectedPurchaser = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a purchaser' : null,
                  ),
                TextFormField(
                  controller: _unitController,
                  decoration: InputDecoration(labelText: 'Unit'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter unit' : null,
                ),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveTransaction(transactionType),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveTransaction(String transactionType) async {
    if (_formKey.currentState?.validate() ?? false) {
      final drinkRepository = DrinkRepository();

      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch,
        drinkId: _selectedDrink!.id,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        transactionType: transactionType,
        transactionDate: DateTime.now(),
        purchaserId: transactionType == 'out' ? _selectedPurchaser?.id : null,
        manufacturerId: transactionType == 'in' ? _selectedDrink!.manufacturerId : null,
      );

      if (transactionType == 'in') {
        await drinkRepository.insertInTransaction(transaction);
      } else {
        await drinkRepository.insertOutTransaction(transaction);
      }

      setState(() {
        transactions.add(transaction);
      });

      Navigator.pop(context);
      _clearForm();
    }
  }

  void _clearForm() {
    _unitController.clear();
    _priceController.clear();
    _quantityController.clear();
    _selectedDrink = null;
    _selectedPurchaser = null;
  }

  @override
  void dispose() {
    _unitController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
