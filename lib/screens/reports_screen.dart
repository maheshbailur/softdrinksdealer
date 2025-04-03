import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/drink_repository.dart';
import '../repositories/transactions_repository.dart';
import '../models/drink.dart';
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'week';
  final DrinkRepository _drinkRepository = DrinkRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  
  // Data holders
  List<Drink> _drinks = [];
  double _totalRevenue = 0;
  double _totalExpenses = 0;
  double _netProfit = 0;
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _outOfStockItems = 0;
  String _mostPopularItem = '';
  List<FlSpot> _salesSpots = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load drinks data
    _drinks = await _drinkRepository.getAllDrinks();
    
    // Calculate inventory metrics
    _totalItems = _drinks.length;
    _lowStockItems = _drinks.where((drink) => drink.stock < 10).length;
    _outOfStockItems = _drinks.where((drink) => drink.stock == 0).length;

    // Get transactions for the selected period
    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();

    // Get IN and OUT transactions
    List<InTransaction> inTransactions = 
        await _transactionRepository.getInTransactionsByDateRange(startDate, endDate);
    List<OutTransaction> outTransactions = 
        await _transactionRepository.getOutTransactionsByDateRange(startDate, endDate);

    // Calculate financial metrics
    // _totalExpenses = inTransactions.fold(0, (sum, tr) => sum + (tr.price * tr.quantity));
    // _totalRevenue = outTransactions.fold(0, (sum, tr) => sum + (tr.price * tr.quantity));
    _totalExpenses = inTransactions.fold(0, (sum, tr) => sum + tr.price);
    _totalRevenue = outTransactions.fold(0, (sum, tr) => sum + tr.price);
    _netProfit = _totalRevenue - _totalExpenses;

    // Create sales chart data
    _salesSpots = _createSalesSpots(outTransactions);

    // Find most popular item
    Map<int, int> salesCount = {};
    for (var tr in outTransactions) {
      salesCount[tr.drinkId] = (salesCount[tr.drinkId] ?? 0) + tr.quantity;
    }
    
    if (salesCount.isNotEmpty) {
      int mostSoldDrinkId = salesCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      Drink? mostSoldDrink = await _drinkRepository.getDrink(mostSoldDrinkId);
      _mostPopularItem = mostSoldDrink?.name ?? 'Unknown';
    } else {
      _mostPopularItem = 'No sales data';
    }

    setState(() {});
  }

  DateTime _getStartDate() {
    DateTime now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        return now.subtract(Duration(days: 7));
      case 'month':
        return DateTime(now.year, now.month - 1, now.day);
      case 'quarter':
        return DateTime(now.year, now.month - 3, now.day);
      case 'year':
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  List<FlSpot> _createSalesSpots(List<OutTransaction> transactions) {
    if (transactions.isEmpty) return [FlSpot(0, 0)];

    Map<int, double> dailySales = {};
    DateTime startDate = _getStartDate();
    int totalDays = DateTime.now().difference(startDate).inDays;

    for (var tr in transactions) {
      int daysDiff = tr.transactionDate.difference(startDate).inDays;
      dailySales[daysDiff] = (dailySales[daysDiff] ?? 0) + (tr.price * tr.quantity);
    }

    List<FlSpot> spots = [];
    for (int i = 0; i <= totalDays; i++) {
      spots.add(FlSpot(i.toDouble(), dailySales[i] ?? 0));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              SizedBox(height: 20),
              _buildSalesChart(),
              SizedBox(height: 20),
              _buildProfitLossCard(),
              SizedBox(height: 20),
              _buildInventorySummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return DropdownButton<String>(
      value: _selectedPeriod,
      items: ['week', 'month', 'quarter', 'year'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value.toUpperCase()),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPeriod = newValue!;
        });
        _loadData(); // Reload data when period changes
      },
    );
  }

  Widget _buildSalesChart() {
    return Container(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _salesSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit/Loss Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Revenue:'),
                Text('\$${_totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Expenses:'),
                Text('\$${_totalExpenses.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Profit:'),
                Text('\$${_netProfit.toStringAsFixed(2)}',
                    style: TextStyle(color: _netProfit >= 0 ? Colors.green : Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySummary() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _buildInventoryRow('Total Items', _totalItems.toString()),
            _buildInventoryRow('Low Stock Items', _lowStockItems.toString()),
            _buildInventoryRow('Out of Stock', _outOfStockItems.toString()),
            _buildInventoryRow('Most Popular', _mostPopularItem),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }
}
