import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/drink.dart';
import '../repositories/drink_repository.dart';
import '../repositories/manufacturer_repository.dart';
import '../models/manufacturer.dart';
import '../database/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Drink> drinks = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  String _selectedCategory = 'Soft Drinks';
  final _unitController = TextEditingController();
  int? _selectedManufacturer;
  // List<String> _manufacturers = [];
  List<Manufacturer> _manufacturers = [];


  final List<String> _categories = [
    'Soft Drinks',
    'Energy Drinks',
    'Juices',
    'Water',
  ];

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
    _loadDrinks();
  }

  Future<void> _loadManufacturers() async {
    try {
      final manufacturers = await ManufacturerRepository().getAllManufacturers();
      setState(() {
        _manufacturers = manufacturers;
      });
    } catch (e) {
      print('Error loading manufacturers: \$e');
    }
  }

  Future<void> _loadDrinks() async {
    try {
      // ✅ Fetch drinks using DrinkRepository
      drinks = await DrinkRepository().getAllDrinks();
      print("Drinks List: $drinks");

      setState(() {}); // ✅ Refresh UI after fetching data
    } catch (e) {
      print('Error loading drinks: $e');
    }
  }

  Future<int> _addNewManufacturer(String name) async {
    final db = await DatabaseHelper.instance.database;
    int manufacturerId = await db.insert('Manufacturers', {'name': name});
    await _loadManufacturers(); // Reload dropdown options
    return manufacturerId;
  }

  Future<void> _deleteManufacturer(int manufacturerId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final inUse = await _isManufacturerInUse(manufacturerId);

      if (inUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot delete manufacturer that is in use'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await db.delete(
        'Manufacturers',
        where: 'id = ?',
        whereArgs: [manufacturerId],
      );

      await _loadManufacturers(); // ✅ Reload manufacturer list

      setState(() {}); // ✅ Refresh UI after deletion

    } catch (e) {
      print('Error deleting manufacturer: $e');
    }
  }

  Future<bool> _isManufacturerInUse(int manufacturerId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'Drinks',
      where: 'manufacturer_id = ?',
      whereArgs: [manufacturerId],
    );
    return result.isNotEmpty;
  }


  Future<void> _saveDrink() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final db = await DatabaseHelper.instance.database;

        final drink = Drink(
          id: 0, // Let SQLite auto-increment handle the ID
          name: _nameController.text,
          manufacturerId: _selectedManufacturer,
          category: _selectedCategory,          
          stock: 0, // Stock starts at zero, updated via IN_Transactions
        );

        await db.insert(
          'Drinks',
          drink.toMap()..remove('id'), // Remove id to let SQLite handle it
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        Navigator.pop(context);
        _clearForm();

        // Refresh the drinks list
        await _loadDrinks();
      } catch (e) {
        print('Error saving drink: $e');
      }
    }
  }


  void _clearForm() {
    _nameController.clear();
    _purchasePriceController.clear();
    _sellingPriceController.clear();
    _selectedCategory = 'Soft Drinks';
    _unitController.clear();
    _selectedManufacturer = _manufacturers.isNotEmpty ? _manufacturers.first.id : null; // ✅ Use null-safe initialization
  }

  void _editDrink(Drink drink) {
    // Implement edit functionality
    _nameController.text = drink.name;
    // _selectedManufacturer = drink.manufacturerId.name;
    // _purchasePriceController.text = drink.purchasePrice.toString();
    // _selectedCategory = drink.category;
    _unitController.text = drink.stock.toString();

    _showAddDrinkDialog();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDrinks(); // Ensure drinks list is refreshed when screen is revisited
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Management'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: drinks.length,
              itemBuilder: (context, index) {
                final drink = drinks[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(drink.name),
                    subtitle: Text('${drink.manufacturerName} - ${drink.category}'),
                    trailing: Text('${drink.stock}'),
                    onTap: () => _editDrink(drink),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDrinkDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddDrinkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Drink'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drink Name Input
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter name' : null,
                ),

                // Manufacturer Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedManufacturer ?? -1,
                  decoration: InputDecoration(labelText: 'Manufacturer'),
                  items: [
                    ..._manufacturers.map((manufacturer) => DropdownMenuItem<int>(
                          value: manufacturer.id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(manufacturer.name), // Manufacturer Name
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.red, size: 18),
                                onPressed: () {
                                  _showDeleteManufacturerDialog(manufacturer.id, manufacturer.name);
                                },
                              ),
                            ],
                          ),
                        )),
                    DropdownMenuItem<int>(
                      value: -1,
                      child: Text('+ Add New'),
                    ),
                  ],
                  onChanged: (int? newValue) {
                    if (newValue == -1) {
                      _showAddManufacturerDialog();
                    } else if (newValue != null) {
                      setState(() {
                        _selectedManufacturer = newValue;
                      });
                    }
                  },
                  validator: (value) => (value == null || value == -1) ? 'Please select a manufacturer' : null,
                ),
                // Purchase Price Input (Stored in IN_Transactions)
                // TextFormField(
                //   controller: _purchasePriceController,
                //   decoration: InputDecoration(labelText: 'Purchase Price'),
                //   keyboardType: TextInputType.number,
                //   validator: (value) =>
                //       value?.isEmpty ?? true ? 'Please enter purchase price' : null,
                // ),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(labelText: 'Category'),
                  items: _categories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                  validator: (value) =>
                      value == null ? 'Please select a category' : null,
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
            onPressed: _saveDrink,
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddManufacturerDialog() async {
    final newManufacturer = await showDialog<Manufacturer>(
      context: context,
      builder: (context) {
        String manufacturerName = '';
        return AlertDialog(
          title: Text('Add Manufacturer'),
          content: TextField(
            onChanged: (value) => manufacturerName = value,
            decoration: InputDecoration(labelText: 'Manufacturer Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (manufacturerName.isNotEmpty) {
                  final newId = await ManufacturerRepository().insertManufacturer(manufacturerName);
                  Navigator.pop(context, Manufacturer(id: newId, name: manufacturerName));
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );

    if (newManufacturer != null) {
      await _loadManufacturers(); // Reload manufacturers list from DB
      Navigator.pop(context); // Close current dialog
      Future.delayed(Duration(milliseconds: 300), () {
        _showAddDrinkDialog(); // Reopen with updated list
      });
    }
  }

  void _showDeleteManufacturerDialog(int manufacturerId, String manufacturerName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete Manufacturer'),
        content: Text('Are you sure you want to delete "$manufacturerName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteManufacturer(manufacturerId); // ✅ Delete and wait
              Navigator.pop(context); // ✅ Close after deletion
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}
