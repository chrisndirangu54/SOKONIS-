import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/services/ai_service.dart';

class SalesDataProvider with ChangeNotifier {
  List<BarChartGroupData> _salesData = [];
  String _insights = '';
  String _recommendations = '';

  List<BarChartGroupData> get salesData => _salesData;
  String get insights => _insights;
  String get recommendations => _recommendations;

  Future<void> getSalesDataFromInsights(
      List<Map<String, dynamic>> productData, String productId) async {
    AIService aiService = AIService();
    final result = await aiService.getProductInsights(productData, productId);

    if (result.isNotEmpty) {
      _salesData = parseSalesData(result['salesData']);
      _insights = result['insights'] ?? '';
      _recommendations = result['recommendations'] ?? '';
      notifyListeners();
    }
  }

  List<BarChartGroupData> parseSalesData(List<dynamic> data) {
    return data.map((product) {
      return BarChartGroupData(
        x: product['day'], // 'day' refers to x-axis labels (e.g., day of week)
        barRods: [
          BarChartRodData(
            toY: product['sales'].toDouble(), // Sales number for y-axis
            color: Colors.blue,
          ),
        ],
      );
    }).toList();
  }
}

class SalesChart extends StatelessWidget {
  final List<BarChartGroupData> salesData;

  const SalesChart({super.key, required this.salesData});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100, // Define max value for better scaling
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Day ${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          checkToShowHorizontalLine: (value) => value % 20 == 0,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.5),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.black.withOpacity(0.5), width: 2),
            bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 2),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'Sales: ${rod.toY.toString()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        barGroups: salesData.map((groupData) {
          return BarChartGroupData(
            x: groupData.x,
            barRods: groupData.barRods.map((rodData) {
              return BarChartRodData(
                toY: rodData.toY,
                color: Colors.blueAccent,
                width: 15,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: Colors.blue.withOpacity(0.2),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
