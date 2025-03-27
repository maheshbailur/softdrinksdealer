import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // For charts

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Stats Cards
              Row(
                children: [
                  _buildStatCard('Total Stock', '1,234 units'),
                  _buildStatCard('Today\'s Sales', '\$1,234'),
                  _buildStatCard('Monthly Profit', '\$5,678'),
                ],
              ),
              SizedBox(height: 20),
              // Add more widgets for charts and tables
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text(value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
