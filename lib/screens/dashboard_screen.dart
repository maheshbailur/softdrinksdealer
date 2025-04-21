import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:sqflite/sqflite.dart';
import 'package:excel/excel.dart';
import 'package:logging/logging.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../repositories/drink_repository.dart';
import '../repositories/transactions_repository.dart';
// import '../repositories/drink_repository.dart';
// import '../repositories/purchaser_repository.dart'; // Import PurchaserRepository
// import '../repositories/manufacturer_repository.dart'; // Import ManufacturerRepository
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

final _logger = Logger('DashboardScreen');

class ImportStatus extends StatelessWidget {
  final String message;
  final double? progress;

  const ImportStatus({
    Key? key,
    required this.message,
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DrinkRepository _drinkRepository = DrinkRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  
  int _totalStock = 0;
  double _todaySales = 0;
  double _todayPurchases = 0;
  double _monthlyRevenue = 0;
  double _monthlyExpenses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Get total stock from all drinks
      final drinks = await _drinkRepository.getAllDrinks();
      _totalStock = drinks.fold(0, (sum, drink) => sum + drink.stock);

      // Get today's date range
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(Duration(days: 1));

      // Get today's OUT transactions (sales)
      final todayOutTransactions = await _transactionRepository
          .getOutTransactionsByDateRange(todayStart, todayEnd);
      _todaySales = todayOutTransactions.fold(
          0.0, (sum, tr) => sum + tr.price);

      // Get today's IN transactions (purchases)
      final todayInTransactions = await _transactionRepository
          .getInTransactionsByDateRange(todayStart, todayEnd);
      _todayPurchases = todayInTransactions.fold(
          0.0, (sum, tr) => sum + (tr['price'] as num).toDouble());

      // Get monthly date range
      final monthStart = DateTime(today.year, today.month, 1);
      final monthEnd = DateTime(today.year, today.month + 1, 0);

      // Get monthly transactions
      final monthlyOutTransactions = await _transactionRepository
          .getOutTransactionsByDateRange(monthStart, monthEnd);
      _monthlyRevenue = monthlyOutTransactions.fold(
          0.0, (sum, tr) => sum + tr.price);

      final monthlyInTransactions = await _transactionRepository
          .getInTransactionsByDateRange(monthStart, monthEnd);
      _monthlyExpenses = monthlyInTransactions.fold(
          0.0, (sum, tr) => sum + (tr['price'] as num).toDouble());

      setState(() => _isLoading = false);
    } catch (e) {
      _logger.severe('Error loading dashboard data', e);
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Failed to load dashboard data: ${e.toString()}');
      }
    }
  }

  Future<void> _resetAllData() async {
    try {
      bool? shouldReset = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Reset All Data'),
            content: Text('This will delete all data from all tables. Are you sure?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (shouldReset == true && mounted) {
        await DatabaseHelper.instance.clearTables();
        await _loadDashboardData(); // Reload dashboard data
        
        if (mounted) {  // Check if widget is still mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All data has been reset'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error resetting data: $e');
      if (mounted) {  // Check if widget is still mounted before showing error
        _showError('Failed to reset data');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatCurrency(double amount) {
    final indianRupeesFormat = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: 2,
    );
    return indianRupeesFormat.format(amount);
  }

  // Future<bool> _requestStoragePermission() async {
  //   final deviceInfo = DeviceInfoPlugin();
  //   final androidInfo = await deviceInfo.androidInfo;
  //   final sdkInt = androidInfo.version.sdkInt;

  //   if (sdkInt >= 30) {
  //     var status = await Permission.manageExternalStorage.status;
  //     if (!status.isGranted) {
  //       status = await Permission.manageExternalStorage.request();
  //     }
  //     return status.isGranted;
  //   } else {
  //     var status = await Permission.storage.status;
  //     if (!status.isGranted) {
  //       status = await Permission.storage.request();
  //     }
  //     return status.isGranted;
  //   }
  // }

Future<void> _handleImport() async {
  // Create a BuildContext variable to track dialog context
  BuildContext? dialogContext;

  // Show initial progress dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      dialogContext = context;
      return const AlertDialog(
        content: ImportStatus(
          message: 'Starting import...',
        ),
      );
    },
  );

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.isEmpty) {
      if (dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }
      _showSnackBar('No file selected', isError: true);
      return;
    }

    final filePath = result.files.single.path!;
    _updateImportStatus('Reading Excel file...');
    
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final db = await DatabaseHelper.instance.database;
    int totalRows = 0;
    int processedRows = 0;

    // Count total rows first, excluding empty sheets
    for (final entry in excel.tables.entries) {
      final sheet = entry.value;
      if (sheet.rows.length > 1) { // Check for more than just header
        // Count non-empty rows
        int nonEmptyRows = sheet.rows.skip(1).where((row) => 
          row.any((cell) => cell?.value != null)).length;
        totalRows += nonEmptyRows;
      }
    }

    if (totalRows == 0) {
      if (dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }
      _showSnackBar('No data found in the Excel file', isError: true);
      return;
    }

    // Use a single transaction for all operations
    await db.transaction((txn) async {
      for (final entry in excel.tables.entries) {
        final sheetName = entry.key;
        final sheet = entry.value;
        
        if (sheet.rows.isEmpty) {
          _logger.warning('Skipping empty sheet: $sheetName');
          continue;
        }

        if (sheet.rows.length <= 1) {
          _logger.warning('Skipping sheet with only headers: $sheetName');
          continue;
        }

        _updateImportStatus('Processing sheet: $sheetName');
        
        final columnHeaders = sheet.rows.first
            .map((e) => e?.value?.toString() ?? '')
            .where((header) => header.isNotEmpty)
            .toList();

        if (columnHeaders.isEmpty) {
          _logger.warning('Skipping sheet with no valid headers');
          continue;
        }

        // Process each sheet's data
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.every((cell) => cell == null)) {
            processedRows++;
            continue;
          }

          final data = <String, dynamic>{};
          for (int j = 0; j < columnHeaders.length; j++) {
            if (j >= row.length) continue;
            final key = columnHeaders[j];
            final value = row[j]?.value;
            data[key] = value?.toString();
          }

          await txn.insert(
            sheetName,
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          processedRows++;
          _updateImportProgress(processedRows / totalRows);
        }
      }
    });

    if (dialogContext != null) {
      Navigator.of(dialogContext!).pop();
    }
    await _loadDashboardData();
    
    _showSnackBar(
      'Import successful from file: ${result.files.single.name}',
      isError: false
    );
  } catch (e) {
    if (dialogContext != null) {
      Navigator.of(dialogContext!).pop();
    }
    _logger.severe('Import error', e);
    _showSnackBar(
      'Failed to import data. Please check file format.',
      isError: true
    );
  }
}

// Modify the update methods to use pushReplacement instead of push
void _updateImportStatus(String message) {
  if (!mounted) return;
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, _, __) => AlertDialog(
        content: ImportStatus(message: message),
      ),
      opaque: false,
      barrierDismissible: false,
    ),
  );
}

void _updateImportProgress(double progress) {
  if (!mounted) return;
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, _, __) => AlertDialog(
        content: ImportStatus(
          message: 'Importing data...',
          progress: progress,
        ),
      ),
      opaque: false,
      barrierDismissible: false,
    ),
  );
}

void _showSnackBar(String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ),
  );
}


  Future<void> _handleBackup() async {
    try {
      // 🔐 Request permission
      final manageStatus = await Permission.manageExternalStorage.status;
      PermissionStatus finalStatus = manageStatus;

      if (!manageStatus.isGranted) {
        finalStatus = await Permission.manageExternalStorage.request();
      }

      if (!finalStatus.isGranted) {
        finalStatus = await Permission.storage.request();
      }

      if (!finalStatus.isGranted) {
        _showError('Storage permission is required for backup');
        return;
      }

      // 📂 Get downloads directory
      final Directory downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getExternalStorageDirectory() ?? Directory.systemTemp;

      if (!downloadsDir.existsSync()) {
        _showError('Downloads directory not found');
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${downloadsDir.path}/drinks_inventory_backup_$timestamp.xlsx';

      final excel = Excel.createExcel(); // Creates a new Excel file
      final db = await DatabaseHelper.instance.database;

      // 📄 List of tables to backup
      final tables = [
        'Manufacturers',
        'Purchasers',
        'Drinks',
        'IN_Transactions',
        'OUT_Transactions',
        'Payments',
        'Receivables'
      ];

      for (final table in tables) {
        final List<Map<String, dynamic>> rows = await db.query(table);
        final List<Map> columns = await db.rawQuery('PRAGMA table_info($table)');
        final columnNames = columns.map((col) => col['name'].toString()).toList();

        final sheet = excel[table]; // Automatically creates a sheet

        // Header row
        sheet.appendRow(columnNames);

        // Data rows
        for (final row in rows) {
          final rowData = columnNames.map((col) => row[col]?.toString() ?? '').toList();
          sheet.appendRow(rowData);
        }
      }

      // ✨ Save the Excel file
      final encoded = excel.encode();
      if (encoded != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(encoded);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to: $filePath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to encode Excel file');
      }

    } catch (e) {
      print('Backup error: $e');
      if (mounted) {
        _showError('Failed to create Excel backup: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.import_export),
            tooltip: 'Import/Backup',
            onSelected: (value) async {
              switch (value) {
                case 'import':
                  await _handleImport();
                  break;
                case 'backup':
                  await _handleBackup();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Import Data'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Backup Data'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.delete_forever),
            color: Colors.red,
            onPressed: _resetAllData,
            tooltip: 'Reset All Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Overview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Total Stock',
                            '$_totalStock units',
                            Icons.inventory,
                          ),
                          _buildStatCard(
                            'Today\'s Sales',
                            '₹${_todaySales.toStringAsFixed(2)}',  // Direct use of ₹ symbol
                            Icons.monetization_on,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Today\'s Purchases',
                            '₹${_todayPurchases.toStringAsFixed(2)}',
                            Icons.shopping_cart,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Monthly Overview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Revenue',
                            _formatCurrency(_monthlyRevenue),
                            Icons.trending_up,
                            color: Colors.green,
                          ),
                          _buildStatCard(
                            'Expenses',
                            _formatCurrency(_monthlyExpenses),
                            Icons.trending_down,
                            color: Colors.red,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildProfitCard(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfitCard() {
    final monthlyProfit = _monthlyRevenue - _monthlyExpenses;
    final isProfit = monthlyProfit >= 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Profit/Loss',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isProfit ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  _formatCurrency(monthlyProfit.abs()),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
