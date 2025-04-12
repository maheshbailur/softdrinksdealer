import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this at the top
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';
import '../models/drink.dart';
import '../models/purchaser.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/drink_repository.dart';
import '../repositories/purchaser_repository.dart'; // Import PurchaserRepository
import '../services/invoice_service.dart';

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
    _loadTransactionsByDate(date: DateTime.now()); // Load data with today's date
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

  Future<void> _loadTransactionsByDate({required DateTime date}) async {
    final transactions = await transactionRepository.getTransactionsByDate(date: date);

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

  Future<void> _loadTransactionsByDateRange({required DateTime start, required DateTime end}) async {

    final transactions = await transactionRepository.loadTransactionsForSelectedRange(start, end);

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
    String pickedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.history),
            onSelected: (value) {
              if (value == 'picked_date') {
                showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                ).then((pickedDate) {
                  if (pickedDate != null) {
                  _loadTransactionsByDate(date: pickedDate);
                  }
                });
              } else if (value == 'date_range') {
                showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.light(),
                      child: child!,
                    );
                  },
                ).then((pickedDate) {
                  if (pickedDate != null) {
                    _loadTransactionsByDateRange(
                      start: pickedDate.start, 
                      end: pickedDate.end
                    );
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'picked_date',
                child: Row(
                  children: [
                    Icon(Icons.today, color: Theme.of(context).iconTheme.color),
                    SizedBox(width: 8),
                    Text('a day'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'date_range',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Theme.of(context).iconTheme.color),
                    SizedBox(width: 8),
                    Text('day-range'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _transactions.isEmpty
          ? Center(child: Text('No transactions'))
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
            heroTag: 'btn1',
          ),
          SizedBox(width: 10),
          FloatingActionButton.extended(
            onPressed: () => _showTransactionDialog('out'),
            label: Text('OUT'),
            icon: Icon(Icons.remove),
            heroTag: 'btn2',
          ),
          SizedBox(width: 10),
          FloatingActionButton.extended(
            onPressed: () => _generateInvoice(),
            label: Text('Invoice'),
            icon: Icon(Icons.receipt),
            heroTag: 'btn3',
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                                  icon: Icon(Icons.close, color: Colors.red, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () async  {
                                    Navigator.pop(context);
                                    await _deletePurchaser(purchaser);

                                    // Update the dialog state
                                    setDialogState(() {
                                      // If the deleted purchaser was selected, clear the selection
                                      if (_selectedPurchaser?.id == purchaser.id) {
                                        _selectedPurchaser = null;
                                      }
                                    });
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
                          Purchaser? newPurchaser = await _showAddPurchaserDialog();
                          if (newPurchaser != null) {
                            setState(() {
                              purchasers.add(newPurchaser);
                            });
                            setDialogState(() {
                              _selectedPurchaser = newPurchaser;
                            });
                          }
                        } else {
                          setDialogState(() {
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

      await _loadTransactionsByDate(date: DateTime.now()); // Refresh transaction list
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
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purchaser added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    Navigator.pop(context, purchaser);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding purchaser: $e'),
                      backgroundColor: Colors.red,
                    ),
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
    try {
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

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchaser deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting purchaser: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _isPurchaserInUse(int purchaserId) async {
    final transactions = await transactionRepository.getTransactionsByPurchaser(purchaserId);
    return transactions.isNotEmpty;
  }

  void _generateInvoice() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No transactions available for invoice generation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final outTransactions = _transactions.where((txn) => txn['type'] == 'OUT').toList();
    
    if (outTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No OUT transactions available for invoice generation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final invoiceService = InvoiceService();
      await invoiceService.generateInvoice(outTransactions);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
