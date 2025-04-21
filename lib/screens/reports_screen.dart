import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/drink_repository.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/purchaser_repository.dart';
import '../models/drink.dart';
import '../models/out_transaction.dart';
import 'dart:math' show pi;
import 'package:intl/intl.dart';

class DetailedDataPoint {
  final DateTime date;
  double totalValue; // Removed final
  final Map<String, double> purchaserBreakdown;
  final Map<String, double> manufacturerBreakdown;

  DetailedDataPoint({
    required this.date,
    required this.totalValue,
    required this.purchaserBreakdown,
    required this.manufacturerBreakdown,
  });
}

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

  static const Map<String, String> dataTypes = {
    'SALES': 'SALES',
    'PURCHASES': 'PURCHASE',
    'PROFIT': 'PROFIT/LOSS',
    'INVENTORY': 'INVENTORY LEVELS',
  };

  String _selectedPeriod = 'week';
  String _selectedDataType = 'SALES'; // Add this line
  String _selectedGraphType = 'LINE'; // Default graph type
  final DrinkRepository _drinkRepository = DrinkRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  final PurchaserRepository _purchaserRepository = PurchaserRepository(); // Add this line

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
  Map<int, DetailedDataPoint> _detailedData = {}; // Add detailed data

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

    // Get transactions with manufacturer information included
    var inTransactions = await _transactionRepository.getInTransactionsByDateRange(startDate, endDate);
    List<OutTransaction> outTransactions = 
        await _transactionRepository.getOutTransactionsByDateRange(startDate, endDate);

    // Calculate financial metrics
    _totalExpenses = inTransactions.fold(0, (sum, tr) => sum + (tr['price'] as num).toDouble());
    _totalRevenue = outTransactions.fold(0, (sum, tr) => sum + tr.price);
    _netProfit = _totalRevenue - _totalExpenses;

    // Create sales chart data
    _salesSpots = _createSalesSpots(outTransactions, inTransactions);
    await _createDetailedData(outTransactions, inTransactions);

    // Find most popular item
    Map<int, int> salesCount = {};
    for (var tr in outTransactions) {
      salesCount[tr.drinkId] = (salesCount[tr.drinkId] ?? 0) + tr.quantity;
    }
    
    if (salesCount.isNotEmpty) {
      int mostSoldDrinkId = salesCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      Drink? mostSoldDrink = await _drinkRepository.getDrink(mostSoldDrinkId);
      _mostPopularItem = mostSoldDrink?.name ?? 'Unknown';
    } else {
      _mostPopularItem = 'No sales data';
    }

    setState(() {});
  }

  Future<void> _createDetailedData(List<OutTransaction> outTransactions, List<Map<String, dynamic>> inTransactions) async {
    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();

    Map<DateTime, DetailedDataPoint> detailedDataMap = {};

    // First initialize all dates
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      detailedDataMap[currentDate] = DetailedDataPoint(
        date: currentDate,
        totalValue: 0,
        purchaserBreakdown: {},
        manufacturerBreakdown: {},
      );
    }

    // Process out transactions
    if (_selectedDataType == 'SALES') {
      for (var tr in outTransactions) {
        DateTime transactionDate = DateTime(
          tr.transactionDate.year,
          tr.transactionDate.month,
          tr.transactionDate.day,
        );

        if (detailedDataMap.containsKey(transactionDate)) {
          detailedDataMap[transactionDate]!.totalValue += tr.price;

          final purchaser = await _purchaserRepository.getPurchaser(tr.purchaserId);
          String purchaserName = purchaser?.name ?? 'Unknown Purchaser';
          
          detailedDataMap[transactionDate]!.purchaserBreakdown[purchaserName] =
              (detailedDataMap[transactionDate]!.purchaserBreakdown[purchaserName] ?? 0) + tr.price;
        }
      }
    }

    // Process in transactions
    if (_selectedDataType == 'PURCHASES') {
      for (var tr in inTransactions) {
        DateTime transactionDate = DateTime.parse(tr['transaction_date']);
        transactionDate = DateTime(
          transactionDate.year,
          transactionDate.month,
          transactionDate.day,
        );

        if (detailedDataMap.containsKey(transactionDate)) {
          String manufacturerName = tr['manufacturer_name'] ?? 'Unknown Manufacturer';
          double price = (tr['price'] as num).toDouble();
          
          detailedDataMap[transactionDate]!.manufacturerBreakdown[manufacturerName] =
              (detailedDataMap[transactionDate]!.manufacturerBreakdown[manufacturerName] ?? 0) + price;
              
          // Update total value after adding to manufacturer breakdown
          detailedDataMap[transactionDate]!.totalValue = 
              detailedDataMap[transactionDate]!.manufacturerBreakdown.values.fold(0, (sum, value) => sum + value);
        }
      }
    }

    // Update the _detailedData map
    setState(() {
      _detailedData = detailedDataMap.map((key, value) => MapEntry(
        key.difference(startDate).inDays,
        value,
      ));
    });
  }

  DateTime _getStartDate() {
    DateTime now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        // Go back 7 days from today to show 8 days total (including today)
        return DateTime(now.year, now.month, now.day - 7);
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
        // Go back 5 years from current year (to show 6 years including current)
        return DateTime(now.year - 5, 1, 1);
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  List<FlSpot> _createSalesSpots(List<OutTransaction> outTransactions, [List<Map<String, dynamic>>? inTransactions]) {
    switch (_selectedDataType) {
      case 'PURCHASES':
        return _createPurchaseSpots(inTransactions ?? []);
      case 'PROFIT':
        return _createProfitSpots(outTransactions, inTransactions ?? []);
      case 'INVENTORY':
        return _createInventorySpots();
      case 'SALES':
      default:
        return _createSalesDataSpots(outTransactions);
    }
  }

  List<FlSpot> _createSalesDataSpots(List<OutTransaction> transactions) {
    if (transactions.isEmpty) return [FlSpot(0, 0)];

    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();

    if (_selectedPeriod == 'week') {
      Map<DateTime, double> dailySales = {};

      // Initialize exactly 8 days (including today)
      for (int i = 0; i < 8; i++) {
        DateTime day = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + i,
        );
        dailySales[day] = 0;
      }

      // Add sales data
      for (var tr in transactions) {
        DateTime transactionDate = DateTime(
          tr.transactionDate.year,
          tr.transactionDate.month,
          tr.transactionDate.day,
        );
        if (tr.transactionDate.isAfter(startDate.subtract(Duration(days: 1))) &&
            tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
          dailySales[transactionDate] = (dailySales[transactionDate] ?? 0) + tr.price;
        }
      }

      // Convert to list of spots
      List<FlSpot> spots = [];
      var sortedDates = dailySales.keys.toList()..sort();
      for (int i = 0; i < sortedDates.length; i++) {
        spots.add(FlSpot(i.toDouble(), dailySales[sortedDates[i]] ?? 0));
      }

      return spots;
    } else if (_selectedPeriod == 'quarter') {
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
    } else if (_selectedPeriod == 'year') {
      Map<int, double> yearlySales = {};

      // Initialize 6 years starting from startDate
      for (int i = 0; i < 6; i++) {
        int year = startDate.year + i;
        yearlySales[year] = 0;
      }

      // Aggregate sales by year
      for (var tr in transactions) {
        if (tr.transactionDate.isAfter(startDate.subtract(Duration(days: 1))) &&
            tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
          int year = tr.transactionDate.year;
          yearlySales[year] = (yearlySales[year] ?? 0) + tr.price;
        }
      }

      // Convert to spots
      List<FlSpot> spots = [];
      var sortedYears = yearlySales.keys.toList()..sort();
      for (int i = 0; i < sortedYears.length; i++) {
        spots.add(FlSpot(i.toDouble(), yearlySales[sortedYears[i]] ?? 0));
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

  List<FlSpot> _createPurchaseSpots(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return [FlSpot(0, 0)];
    
    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();
    
    Map<DateTime, double> dailyPurchases = {};
    // Initialize dates
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      dailyPurchases[startDate.add(Duration(days: i))] = 0;
    }

    // Aggregate purchase data
    for (var tr in transactions) {
      DateTime transactionDate = DateTime.parse(tr['transaction_date']);
      if (transactionDate.isAfter(startDate) &&
          transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
        DateTime purchaseDate = DateTime(
          transactionDate.year,
          transactionDate.month,
          transactionDate.day,
        );
        dailyPurchases[purchaseDate] = (dailyPurchases[purchaseDate] ?? 0) + (tr['price'] as num).toDouble();
      }
    }

    // Convert to spots
    List<FlSpot> spots = [];
    var sortedDates = dailyPurchases.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyPurchases[sortedDates[i]] ?? 0));
    }

    return spots;
  }

  List<FlSpot> _createProfitSpots(List<OutTransaction> outTransactions, List<Map<String, dynamic>> inTransactions) {
    DateTime startDate = _getStartDate();
    DateTime endDate = DateTime.now();
    
    Map<DateTime, double> dailyProfit = {};
    // Initialize dates
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      dailyProfit[startDate.add(Duration(days: i))] = 0;
    }

    // Calculate daily revenue
    for (var tr in outTransactions) {
      if (tr.transactionDate.isAfter(startDate) &&
          tr.transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
        DateTime saleDate = DateTime(
          tr.transactionDate.year,
          tr.transactionDate.month,
          tr.transactionDate.day,
        );
        dailyProfit[saleDate] = (dailyProfit[saleDate] ?? 0) + tr.price;
      }
    }

    // Subtract daily expenses
    for (var tr in inTransactions) {
      DateTime transactionDate = DateTime.parse(tr['transaction_date']);
      if (transactionDate.isAfter(startDate) &&
          transactionDate.isBefore(endDate.add(Duration(days: 1)))) {
        DateTime purchaseDate = DateTime(
          transactionDate.year,
          transactionDate.month,
          transactionDate.day,
        );
        dailyProfit[purchaseDate] = (dailyProfit[purchaseDate] ?? 0) - (tr['price'] as num).toDouble();
      }
    }

    // Convert to spots
    List<FlSpot> spots = [];
    var sortedDates = dailyProfit.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyProfit[sortedDates[i]] ?? 0));
    }

    return spots;
  }

  List<FlSpot> _createInventorySpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < _drinks.length; i++) {
      spots.add(FlSpot(i.toDouble(), _drinks[i].stock.toDouble()));
    }
    return spots;
  }

  String _getQuarterKey(DateTime date) {
    int year = date.year;
    int quarter = ((date.month - 1) ~/ 3) + 1;
    return '$year-Q$quarter';
  }

  String get _chartTitle {
    return dataTypes[_selectedDataType] ?? 'Sales Data';
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPeriod,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        isDense: true,
                      ),
                      items: ['week', 'month', 'quarter', 'year'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value.toUpperCase(),
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPeriod = newValue!;
                        });
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedDataType,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        isDense: true,
                      ),
                      items: dataTypes.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value,
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDataType = newValue!;
                        });
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedGraphType,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        isDense: true,
                      ),
                      items: ['LINE', 'BLOCK', 'PI'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGraphType = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10), // Reduce gap between dropdowns and chart
              _buildSalesChart(),
              SizedBox(height: 10), // Reduce gap between chart and index
              _buildProfitLossCard(),
              SizedBox(height: 20),
              _buildInventorySummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _chartTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        switch (_selectedGraphType) {
          'BLOCK' => _buildBarChart(),
          'PI' => _buildPieChart(),
          'LINE' => _buildChart(),
          _ => _buildChart(),
        }
      ],
    );
  }

  Widget _buildChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
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
          lineTouchData: _selectedDataType == 'PROFIT' || _selectedDataType == 'INVENTORY' 
            ? LineTouchData(enabled: true)  // Basic touch data without callback for these types
            : LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                ),
                touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (event is FlTapUpEvent && touchResponse?.lineBarSpots != null) {
                    final spotIndex = touchResponse!.lineBarSpots![0].spotIndex;
                    _showDetailedBreakdown(spotIndex);
                  }
                },
              ),
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

  void _showDetailedBreakdown(int spotIndex) {
    if (!_detailedData.containsKey(spotIndex)) return;

    final data = _detailedData[spotIndex]!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Breakdown for ${DateFormat('MMM dd, yyyy').format(data.date)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Value: ₹${data.totalValue.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      
                      // Show purchaser breakdown only for SALES data type
                      if (_selectedDataType == 'SALES') ...[
                        _buildBreakdownSection('By Purchaser', data.purchaserBreakdown),
                        SizedBox(height: 20),
                      ],
                      
                      // Show manufacturer breakdown only for PURCHASES data type
                      if (_selectedDataType == 'PURCHASES')
                        _buildBreakdownSection('By Manufacturer', data.manufacturerBreakdown),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownSection(String title, Map<String, double> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...data.entries.map((e) => Padding(
          padding: EdgeInsets.only(left: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(e.key)),
              Text('₹${e.value.toStringAsFixed(2)}'),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildBarChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: _salesSpots.map((spot) {
            return BarChartGroupData(
              x: spot.x.toInt(),
              barRods: [
                BarChartRodData(
                  toY: spot.y,
                  color: Colors.blue,
                  width: 15,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
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
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    double total = _salesSpots.fold(0, (sum, spot) => sum + spot.y);
    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];

    for (int i = 0; i < _salesSpots.length; i++) {
      final spot = _salesSpots[i];
      if (spot.y == 0) continue; // Skip indices with no value

      double percentage = (spot.y / total) * 100;
      Color color = Colors.primaries[i % Colors.primaries.length];

      // Add section to the pie chart
      sections.add(PieChartSectionData(
        value: spot.y,
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 100,
      ));

      // Add corresponding legend item
      DateTime startDate = _getStartDate();
      String dateLabel = _selectedPeriod == 'week'
          ? '${startDate.add(Duration(days: i)).day}/${_getShortMonthName(startDate.month)}'
          : _getXAxisLabel(i);

      legendItems.add(Row(
        children: [
          Container(
            width: 12,
            height: 12,
            color: color,
          ),
          SizedBox(width: 8),
          Text(dateLabel, style: TextStyle(fontSize: 12)),
        ],
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        SizedBox(height: 10), // Reduce gap between chart and index
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 columns
            childAspectRatio: 3, // Adjust height-to-width ratio
          ),
          itemCount: legendItems.length,
          itemBuilder: (context, index) {
            return legendItems[index];
          },
        ),
      ],
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
        return 1; // Show every year
      default:
        return 1;
    }
  }

  String _getXAxisLabel(int value) {
    DateTime startDate = _getStartDate();
    switch (_selectedPeriod) {
      case 'week':
        final date = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + value,
        );
        return '${date.day}/${_getShortMonthName(date.month)}';
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
        final year = startDate.year + value;
        return year.toString();
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
                Text('\₹${_totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Expenses:'),
                Text('\₹${_totalExpenses.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Profit:'),
                Text('\₹${_netProfit.toStringAsFixed(2)}',
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
