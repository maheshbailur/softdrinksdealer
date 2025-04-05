import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this at the top
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';
import '../models/drink.dart';
import '../models/purchaser.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/drink_repository.dart';
import '../repositories/purchaser_repository.dart'; // Import PurchaserRepository

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
  final _purchaserRepository = PurchaserRepository(); // Initialize PurchaserRepository

  @override
  void initState() {
    super.initState();
    _transactions = []; // Initialize with an empty list
    _loadTransactions(); // Load data
    _loadDrinks(); // Load drinks
    _loadPurchasers(); // Load purchasers
  }

  Future<void> _loadDrinks() async {
    drinks = await drinkRepository.getAllDrinks(); // Ensure this method exists in DrinkRepository
    setState(() {}); // Refresh UI after fetching data
  }

  Future<void> _loadPurchasers() async {
    final loadedPurchasers = await _purchaserRepository.getAllPurchasers();
    setState(() {
      purchasers = loadedPurchasers;
    });
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
    // Reset controllers at the start of dialog
    _priceController.clear();
    _quantityController.clear();
    _selectedDrink = null;
    _selectedPurchaser = null;

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
                      child: Text('${drink.name} (${drink.manufacturerName ?? "Unknown"})'),
                    );
                  }).toList(),
                  onChanged: (Drink? newValue) {
                    setState(() {
                      _selectedDrink = newValue;
                      // Update quantity field with stock value when drink is selected
                      if (newValue != null) {
                        _quantityController.text = transactionType == 'in' 
                            ? '0'  // For IN transactions, start with 0
                            : newValue.stock.toString();  // For OUT transactions, show available stock
                      }
                    });
                  },
                  validator: (value) => value == null ? 'Please select a product' : null,
                ),
                if (transactionType == 'out')
                  DropdownButtonFormField<Purchaser>(
                    value: _selectedPurchaser,
                    decoration: InputDecoration(labelText: 'Purchaser'),
                    items: [
                      ...purchasers.map((Purchaser purchaser) {
                        return DropdownMenuItem<Purchaser>(
                          value: purchaser,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(purchaser.name),
                              IconButton(
                                icon: Icon(Icons.close, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  _deletePurchaser(purchaser);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      DropdownMenuItem<Purchaser>(
                        value: null,
                        child: Text('+ Add New'),
                      ),
                    ],
                    onChanged: (Purchaser? newValue) async {
                      if (newValue == null) {
                        Purchaser? newPurchaser = await _showAddPurchaserDialog(); // Declare the variable here
                        if (newPurchaser != null) {
                          setState(() {
                            purchasers.add(newPurchaser); // Add to the list of purchasers
                            _selectedPurchaser = newPurchaser; // Update selected purchaser
                          });
                        }
                      } else {
                        setState(() {
                          _selectedPurchaser = newValue;
                        });
                      }
                    },
                    validator: (value) => value == null ? 'Please select a purchaser' : null,
                  ),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    helperText: transactionType == 'out' ? 'Maximum available: ${_selectedDrink?.stock ?? 0}' : null,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null || quantity <= 0) {
                      return 'Please enter a valid quantity';
                    }
                    if (transactionType == 'out' && _selectedDrink != null) {
                      if (quantity > _selectedDrink!.stock) {
                        return 'Quantity cannot exceed available stock';
                      }
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

  Future<Purchaser?> _showAddPurchaserDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Purchaser>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Purchaser'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Purchaser Name'),
                validator: (value) => 
                  value?.isEmpty ?? true ? 'Please enter name' : null,
              ),
              TextFormField(
                controller: contactController,
                decoration: InputDecoration(labelText: 'Contact Info'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final id = await _purchaserRepository.insertPurchaser(
                    nameController.text,
                    contactController.text,
                  );
                  
                  if (id != -1) {
                    final purchaser = Purchaser(
                      id: id,
                      name: nameController.text,
                      contactInfo: contactController.text,
                    );
                    Navigator.pop(context, purchaser);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding purchaser: $e')),
                  );
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePurchaser(Purchaser purchaser) async {
    final isInUse = await _isPurchaserInUse(purchaser.id);
    
    if (isInUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete purchaser that is in use'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _purchaserRepository.deletePurchaser(purchaser.id);
    setState(() {
      purchasers.removeWhere((m) => m.id == purchaser.id);
      if (_selectedPurchaser?.id == purchaser.id) {
        _selectedPurchaser = null;
      }
    });
  }

  Future<bool> _isPurchaserInUse(int purchaserId) async {
    final transactions = await transactionRepository.getTransactionsByPurchaser(purchaserId);
    return transactions.isNotEmpty;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
