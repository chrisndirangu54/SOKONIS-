import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/order_provider.dart';
import '../services/rider_location_service.dart';
import '../providers/user_provider.dart';
import '../screens/tracking_screen.dart';
import '../screens/add_review_screen.dart'; // Import the AddReviewScreen

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  OrderDetailsScreenState createState() => OrderDetailsScreenState();
}

class OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool deliveryConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleOrderStatus();
    });
  }

  void _handleOrderStatus() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.pendingOrders.firstWhere(
      (o) => o.orderId == widget.orderId,
      orElse: () => throw Exception('Order not found'),
    );

    if (order.status == 'Rider has arrived') {
      Future.delayed(const Duration(hours: 24), () {
        if (!deliveryConfirmed) {
          setState(() {
            orderProvider.updateOrderStatus(order.orderId, 'Delivered');
          });
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delivery Status'),
                content: const Text(
                    'The order has been automatically marked as delivered.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      });
    }
  }

  // Function to calculate category percentages from items' products
  Map<String, double> calculateCategoryPercentages(order) {
    final categoryCounts = <String, int>{};
    int totalProducts = 0;

    // Count how many products belong to each category
    for (var product in order.items) {
      final category =
          product.product.category; // Assuming category is a String
      if (categoryCounts.containsKey(category)) {
        categoryCounts[category] = categoryCounts[category]! + 1;
      } else {
        categoryCounts[category] = 1;
      }
      totalProducts++;
    }

    // Convert category counts to percentages
    final categoryPercentages = <String, double>{};
    categoryCounts.forEach((category, count) {
      categoryPercentages[category] = count / totalProducts;
    });

    return categoryPercentages;
  }

  // Function to track the budget and alert if overspending
  Widget buildBudgetTracking(OrderProvider orderProvider) {
    // Sample data for budget tracking (would come from user settings)
    const double monthlyBudget = 500.0;
    const double totalSpending = 400.0; // Example of current spending
    const double budgetPercentage = totalSpending / monthlyBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Budget Tracking',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: budgetPercentage,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(
              budgetPercentage > 1 ? Colors.red : Colors.green),
        ),
        const SizedBox(height: 8),
        const Text(
          'You\'ve spent \$$totalSpending out of your \$$monthlyBudget budget this month.',
          style: TextStyle(fontSize: 16),
        ),
        if (budgetPercentage > 1)
          const Text(
            'Warning: You have exceeded your budget!',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildMonthlySpendingGraph(OrderProvider orderProvider) {
    // Sample data for monthly spending (This would normally be fetched from the orderProvider or backend)
    final spendingData = [
      const FlSpot(1, 100), // Day 1: $100
      const FlSpot(5, 150), // Day 5: $150
      const FlSpot(10, 200), // Day 10: $200
      const FlSpot(15, 250), // Day 15: $250
      const FlSpot(20, 180), // Day 20: $180
      const FlSpot(25, 220), // Day 25: $220
    ];

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            verticalInterval: 1,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.blue.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.blue.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.blueAccent, width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spendingData,
              isCurved: true,
              // Using a gradient for the line
              color: Colors.transparent, // Needed for LineChartBarData
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    color: Colors.white,
                    strokeColor: Colors.blueAccent,
                    strokeWidth: 2,
                    radius: 5,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              barWidth: 4,
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
          backgroundColor: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final riderLocationService = RiderLocationService();

    final order = orderProvider.pendingOrders.firstWhere(
      (o) => o.orderId == widget.orderId,
      orElse: () => throw Exception('Order not found'),
    );

    // Dynamically calculate category percentages
    final categoryPercentages = calculateCategoryPercentages(order);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Items:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Description: ${order.orderId}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              const Text('Order Details:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: ${order.status}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              if (order.status == 'On the way') ...[
                Text('Rider Location: ${order.riderLocation}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TrackingScreen(
                        orderId: order.orderId,
                        userProvider: userProvider,
                        riderLocationService: riderLocationService,
                      ),
                    ));
                  },
                  child: const Text('Track Rider'),
                ),
              ],
              const SizedBox(height: 16),
              if (order.status == 'Rider has arrived') ...[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      deliveryConfirmed = true;
                    });
                    orderProvider.updateOrderStatus(order.orderId, 'Delivered');
                  },
                  child: const Text('Confirm Delivery'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      deliveryConfirmed = true;
                    });
                    orderProvider.updateOrderStatus(
                        order.orderId, 'Not Delivered');
                  },
                  child: const Text('Was Not Delivered'),
                ),
                const SizedBox(height: 8),
                const Text(
                    'If no action is taken within 24 hours, the order will be automatically marked as delivered.',
                    style: TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              // Show the 'Leave a Review' button for each product if the order is delivered
              if (order.status == 'Delivered') ...[
                const Text('Products in this order:',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...order.items.map((product) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.product.name,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AddReviewScreen(
                              productId: product.product.id,
                            ),
                          ));
                        },
                        child: const Text('Leave a Review'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ],
              const SizedBox(height: 24),
              // Circular Percent Indicators for Category Percentages
              const Text('Order Categories Breakdown:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: categoryPercentages.entries.map((entry) {
                  return Column(
                    children: [
                      CircularPercentIndicator(
                        radius: 40,
                        lineWidth: 8.0,
                        percent: entry.value,
                        center:
                            Text('${(entry.value * 100).toStringAsFixed(1)}%'),
                        progressColor: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(entry.key, style: const TextStyle(fontSize: 14)),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              buildBudgetTracking(orderProvider),
              const SizedBox(height: 24),
              buildMonthlySpendingGraph(orderProvider),
            ],
          ),
        ),
      ),
    );
  }
}
