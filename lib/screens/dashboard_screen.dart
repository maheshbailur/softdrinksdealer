import 'package:flutter/material.dart';
import '../repositories/drink_repository.dart';
import '../repositories/transactions_repository.dart';
import '../database/database_helper.dart';
// import '../models/drink.dart';
// import '../models/in_transaction.dart;
// import '../models/out_transaction.dart';
import 'package:intl/intl.dart';

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
          0.0, (sum, transaction) => sum + transaction.price);
          // 0.0, (sum, transaction) => sum + (transaction.price * transaction.quantity));

      // Get today's IN transactions (purchases)
      final todayInTransactions = await _transactionRepository
          .getInTransactionsByDateRange(todayStart, todayEnd);
      _todayPurchases = todayInTransactions.fold(
          0.0, (sum, transaction) => sum + (transaction.price * transaction.quantity));

      // Get monthly date range
      final monthStart = DateTime(today.year, today.month, 1);
      final monthEnd = DateTime(today.year, today.month + 1, 0);

      // Get monthly OUT transactions
      final monthlyOutTransactions = await _transactionRepository
          .getOutTransactionsByDateRange(monthStart, monthEnd);
      _monthlyRevenue = monthlyOutTransactions.fold(
          0.0, (sum, transaction) => sum + transaction.price);
          // 0.0, (sum, transaction) => sum + (transaction.price * transaction.quantity));

      // Get monthly IN transactions
      final monthlyInTransactions = await _transactionRepository
          .getInTransactionsByDateRange(monthStart, monthEnd);
      _monthlyExpenses = monthlyInTransactions.fold(
          // 0.0, (sum, transaction) => sum + (transaction.price * transaction.quantity));
          0.0, (sum, transaction) => sum + transaction.price);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load dashboard data');
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
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
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
