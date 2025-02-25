import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/models/order.dart' as model;
import 'package:grocerry/providers/cart_provider.dart';
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
  double _monthlyBudget =
      500.0; // Default value, will be updated from Firestore

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleOrderStatus();
      _loadBudget(); // Load budget when widget initializes
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
  Map<String, double> calculateCategoryPercentages(model.Order order) {
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

  // Load the user's budget from Firestore
  Future<void> _loadBudget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _monthlyBudget =
            (userDoc['monthlyBudget'] as num?)?.toDouble() ?? 500.0;
      });
    }
  }

  // Show dialog to input budget
  Future<void> _showBudgetInputDialog(BuildContext context) async {
    final TextEditingController budgetController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter Budget (\$)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final input = double.tryParse(budgetController.text);
                if (input != null && input > 0) {
                  setState(() {
                    _monthlyBudget = input;
                  });
                  // Save to Firestore
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'monthlyBudget': input});
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Budget updated successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid budget')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget buildBudgetTracking(OrderProvider orderProvider) {
    // Use provider or other source for total spending; hardcoded here for simplicity
    const double totalSpending =
        400.0; // Replace with orderProvider.totalSpending
    final double budgetPercentage = totalSpending / _monthlyBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Budget Tracking',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showBudgetInputDialog(context),
              tooltip: 'Edit Budget',
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: budgetPercentage.clamp(0, 1), // Clamp to avoid overflow in UI
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            budgetPercentage > 1 ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You\'ve spent \$${totalSpending.toStringAsFixed(2)} out of your \$${_monthlyBudget.toStringAsFixed(2)} budget this month.',
          style: const TextStyle(fontSize: 16),
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
                }),
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

class PaymentConfirmationScreen extends StatelessWidget {
  final String orderId;

  const PaymentConfirmationScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Confirm Payment for Order $orderId')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Please select your payment method for order $orderId:'),
            ElevatedButton(
              onPressed: () {
                final cartItems =
                    context.read<CartProvider>().items.values.toList();
                context
                    .read<CartProvider>()
                    .selectPaymentMethodWithoutCOD(cartItems, context);
              },
              child:
                  const Text('Select Payment Method'), // Here you can use const
            ),
          ],
        ),
      ),
    );
  }
}
