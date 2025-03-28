import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this at the top
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';
import '../models/drink.dart';
import '../models/purchaser.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/drink_repository.dart';

class TransactionScreen extends StatefulWidget {
  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Drink> drinks = [];
  List<Purchaser> purchasers = [];

  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  Drink? _selectedDrink;
  Purchaser? _selectedPurchaser; // Only for OUT transactions

  final transactionRepository = TransactionRepository();
  final drinkRepository = DrinkRepository();

  @override
  void initState() {
    super.initState();
    _transactions = []; // Initialize with an empty list
    _loadTransactions(); // Load data
    _loadDrinks(); // Load drinks
  }

  Future<void> _loadDrinks() async {
    drinks = await drinkRepository.getAllDrinks(); // Ensure this method exists in DrinkRepository
    setState(() {}); // Refresh UI after fetching data
  }


  Future<void> _loadTransactions() async {
    final transactions = await transactionRepository.getTodayTransactions();

    setState(() {
      _transactions = List<Map<String, dynamic>>.from(transactions); // ✅ Convert to mutable list

      _transactions.sort((a, b) {
        final dateA = DateTime.parse(a['transaction_date']); 
        final dateB = DateTime.parse(b['transaction_date']);
        return dateB.compareTo(dateA); // Sort latest first
      });
    });

    print("Transactions after sorting: $_transactions");
    print("Rebuilding UI with transactions count: ${_transactions.length}");
  }


  @override
  Widget build(BuildContext context) {
    String todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text('Transactions ($todayDate)')),
      body: _transactions.isEmpty
          ? Center(child: Text('No transactions today'))
          : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final txn = _transactions[index];
                return _buildTransactionCard(txn, txn['type']); // Pass transaction type
              },
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


Widget _buildTransactionCard(Map<String, dynamic> transaction, String type) {
  return Card(
    margin: EdgeInsets.all(8),
    child: ListTile(
      title: Text('$type [${transaction['drink_name']}-${transaction['manufacturer_name'] ?? 'Unknown'}] Qty: ${transaction['quantity']}, Price: ${transaction['price']}'),
      // subtitle: Text('Quantity: ${transaction['quantity']}, Price: ${transaction['price']}'),
    ),
  );
}


  void _showTransactionDialog(String transactionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${transactionType.toUpperCase()} Transaction'),
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
                      child: Text('${drink.name}(${drink.manufacturerName ?? "Unknown"})'),
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
      if (transactionType == 'in') {
        final transaction = InTransaction(
          id: DateTime.now().millisecondsSinceEpoch,
          drinkId: _selectedDrink!.id,
          quantity: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          transactionDate: DateTime.now(),
        );
        await transactionRepository.insertInTransaction(transaction);
      } else {
        final transaction = OutTransaction(
          id: DateTime.now().millisecondsSinceEpoch,
          drinkId: _selectedDrink!.id,
          quantity: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          purchaserId: _selectedPurchaser!.id,
          transactionDate: DateTime.now(),
        );
        await transactionRepository.insertOutTransaction(transaction);
      }

      await _loadTransactions(); // Refresh transaction list
      setState(() {});
      Navigator.pop(context);
      _clearForm();
    }
  }

  void _clearForm() {
    _priceController.clear();
    _quantityController.clear();
    _selectedDrink = null;
    _selectedPurchaser = null;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
