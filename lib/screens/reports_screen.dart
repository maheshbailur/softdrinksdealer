import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/drink_repository.dart';
import '../repositories/transactions_repository.dart';
import '../models/drink.dart';
import '../models/in_transaction.dart';
import '../models/out_transaction.dart';
import 'dart:math' show pi;

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Add these constant widgets
  static const Map<String, Widget> periodLabels = {
    'week': Text('Days', style: TextStyle(fontSize: 12)),
    'month': Text('Months', style: TextStyle(fontSize: 12)),
    'quarter': Text('Quarters', style: TextStyle(fontSize: 12)),
    'year': Text('Years', style: TextStyle(fontSize: 12)),
  };

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
        return DateTime(now.year, now.month - 6, 1);
      case 'quarter':
        // For 4/4/2025, we want to start from Q3 2024
        int currentQuarter = ((now.month - 1) ~/ 3);
        int startYear = now.year;
        int startMonth = (currentQuarter * 3) + 1 - 9; // Go back 3 quarters

        if (startMonth <= 0) {
          startMonth += 12;
          startYear--;
        }
        
        return DateTime(startYear, startMonth, 1);
      case 'year':
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  List<FlSpot> _createSalesSpots(List<OutTransaction> transactions) {
    if (transactions.isEmpty) return [FlSpot(0, 0)];

    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();

    if (_selectedPeriod == 'quarter') {
      Map<String, double> quarterSales = {};
      
      // Initialize 4 quarters starting from startDate
      for (int i = 0; i < 4; i++) {
        DateTime quarterDate = DateTime(
          startDate.year, 
          startDate.month + (i * 3), 
          1
        );
        // Handle year transition
        if (quarterDate.month > 12) {
          quarterDate = DateTime(
            quarterDate.year + 1, 
            quarterDate.month - 12, 
            1
          );
        }
        String quarterKey = _getQuarterKey(quarterDate);
        quarterSales[quarterKey] = 0;
      }

      // Aggregate sales by quarter
      for (var tr in transactions) {
        if (tr.transactionDate.isAfter(startDate.subtract(Duration(days: 1))) && 
            tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
          String quarterKey = _getQuarterKey(tr.transactionDate);
          quarterSales[quarterKey] = (quarterSales[quarterKey] ?? 0) + tr.price;
        }
      }

      // Convert to spots
      List<FlSpot> spots = [];
      var sortedQuarters = quarterSales.keys.toList()..sort();
      for (int i = 0; i < sortedQuarters.length; i++) {
        spots.add(FlSpot(i.toDouble(), quarterSales[sortedQuarters[i]] ?? 0));
      }
      return spots;
    } else if (_selectedPeriod == 'month') {
      Map<DateTime, double> monthlySales = {};
      // Initialize monthly buckets
      for (int i = 0; i <= 5; i++) {
        DateTime monthDate = DateTime(startDate.year, startDate.month + i, 1);
        monthlySales[monthDate] = 0;
      }

      // Aggregate sales by month
      for (var tr in transactions) {
        DateTime monthStart = DateTime(tr.transactionDate.year, tr.transactionDate.month, 1);
        if (tr.transactionDate.isAfter(startDate.subtract(Duration(days: 1))) && 
            tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
          monthlySales[monthStart] = (monthlySales[monthStart] ?? 0) + tr.price;
        }
      }

      // Convert to spots
      List<FlSpot> spots = [];
      var sortedDates = monthlySales.keys.toList()..sort();
      for (int i = 0; i < sortedDates.length; i++) {
        spots.add(FlSpot(i.toDouble(), monthlySales[sortedDates[i]] ?? 0));
      }
      return spots;
    } else {
      Map<DateTime, double> dailySales = {};
      // Initialize all dates in the range with 0
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        dailySales[startDate.add(Duration(days: i))] = 0;
      }

      // Add sales data
      for (var tr in transactions) {
        if (tr.transactionDate.isAfter(startDate) && 
            tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
          dailySales[DateTime(
            tr.transactionDate.year,
            tr.transactionDate.month,
            tr.transactionDate.day,
          )] = (dailySales[tr.transactionDate] ?? 0) + tr.price;
        }
      }

      // Convert to list of spots
      List<FlSpot> spots = [];
      var sortedDates = dailySales.keys.toList()..sort();
      for (int i = 0; i < sortedDates.length; i++) {
        spots.add(FlSpot(i.toDouble(), dailySales[sortedDates[i]] ?? 0));
      }

      return spots;
    }
  }

  String _getQuarterKey(DateTime date) {
    int year = date.year;
    int quarter = ((date.month - 1) ~/ 3) + 1;
    return '$year-Q$quarter';
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
    // Find min and max values for the Y axis
    double maxY = _salesSpots.isEmpty ? 10 : 
      _salesSpots.reduce((a, b) => a.y > b.y ? a : b).y;
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding to max value

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: maxY / 5, // Show 5 horizontal grid lines
            verticalInterval: 1,
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxY / 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('₹${value.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: periodLabels[_selectedPeriod] ?? const Text('Days'),
              sideTitles: SideTitles(
                showTitles: true,
                interval: _getXAxisInterval(),
                getTitlesWidget: (value, meta) {
                  return Transform.rotate(
                    angle: _selectedPeriod == 'week' ? -45 * pi / 180 : 0,
                    child: Text(
                      _getXAxisLabel(value.toInt()),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: _salesSpots.isEmpty ? 10 : _salesSpots.length.toDouble() - 1,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: _salesSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  double _getXAxisInterval() {
    switch (_selectedPeriod) {
      case 'week':
        return 1; // Show every day
      case 'month':
        return 1; // Show every month
      case 'quarter':
        return 1; // Show every quarter
      case 'year':
        return 30; // Show every month
      default:
        return 1;
    }
  }

  String _getXAxisLabel(int value) {
    DateTime startDate = _getStartDate();
    switch (_selectedPeriod) {
      case 'week':
        final date = startDate.add(Duration(days: value));
        return '${date.day}/${_getShortMonthName(date.month)}'; // Format: DD/MMM
      case 'month':
        final date = DateTime(startDate.year, startDate.month + value, 1);
        return _getShortMonthName(date.month);
      case 'quarter':
        final quarterStartDate = DateTime(
          startDate.year, 
          startDate.month + (value * 3), 
          1
        );
        final quarterEndDate = DateTime(
          quarterStartDate.year, 
          quarterStartDate.month + 2, 
          1
        );
        return '${_getShortMonthName(quarterStartDate.month)}-'
               '${_getShortMonthName(quarterEndDate.month)}/'
               '${quarterStartDate.year.toString().substring(2)}';
      case 'year':
        final date = DateTime(startDate.year, startDate.month + value);
        return _getShortMonthName(date.month);
      default:
        return value.toString();
    }
  }

  String _getShortMonthName(int month) {
    const monthNames = {
      1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'May', 6: 'Jun',
      7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec'
    };
    return monthNames[month] ?? '';
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
