import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/sales_data_provider.dart';
import '../screens/order_details_screen.dart';
import '../providers/product_provider.dart';
import 'package:grocerry/models/order.dart' as model;

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  AllOrdersScreenState createState() => AllOrdersScreenState();
}

class AllOrdersScreenState extends State<AllOrdersScreen> {
  List<model.Order>? allOrders; // Replace with your actual data source
  model.Order? order; // Replace with your actual data source
  @override
  void initState() {
    super.initState();
    // Simulate loading orders (replace with your data fetch logic)
    allOrders = [];
  }

  // Cancel an order
  Future<void> _cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': 'Cancelled'});
      setState(() {
        final order = allOrders!.firstWhere((o) => o.orderId == orderId);
        order.status = 'Cancelled';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel order')),
      );
    }
  }

  // Blacklist a user
  Future<void> _blacklistUser(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .update({'isBlacklisted': true});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blacklisted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to blacklist user')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final salesDataProvider = Provider.of<SalesDataProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    // Fetch the list of all orders
    final allOrders = orderProvider.allOrders;
    final products = productProvider.products;
    String? productId; // Track selected product ID

    // Placeholder data for order summations (replace with actual data)
    final orderSummations = [
      OrderSummation('Daily', 150),
      OrderSummation('Weekly', 800),
      OrderSummation('Monthly', 3500),
      OrderSummation('Yearly', 42000),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'All Orders',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Product Dropdown Selection
            DropdownButton<String>(
              value: productId,
              hint: const Text(
                'Select a Product',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              isExpanded: true,
              items: products.map((product) {
                return DropdownMenuItem<String>(
                  value: product.id,
                  child: Text(product.name),
                );
              }).toList(),
              onChanged: (newValue) async {
                productId = newValue;

                if (newValue != null) {
                  // Fetch product data from ProductProvider
                  final selectedProductData = await productProvider
                      .getProductDataFromFirestore(newValue);

                  // If product data is successfully fetched, pass it to SalesDataProvider
                  if (selectedProductData != null) {
                    await salesDataProvider.getSalesDataFromInsights(
                        [selectedProductData], newValue);
                  }
                }
              },
            ),
            const SizedBox(height: 20),

            // Order Summation Chart with Enhanced Bento Styling
            SizedBox(
              height: 220,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      20), // Softer edges for a modern look
                ),
                elevation: 5, // Slightly higher elevation for a floating effect
                shadowColor:
                    Colors.grey.withOpacity(0.2), // Light shadow for depth
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Summations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceBetween,
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '\$${value.toInt()}', // Formatting values with $
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final dateLabel = orderSummations[
                                            value.toInt()]
                                        .date; // Assuming a date field exists
                                    return Text(
                                      dateLabel as String,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine:
                                  false, // Only horizontal grid lines
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.shade300,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            barGroups:
                                orderSummations.asMap().entries.map((entry) {
                              final index = entry.key;
                              final summation = entry.value;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: summation.amount.toDouble(),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade700,
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ), // Gradient fill
                                    width: 20, // Slightly wider bars
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(8)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sales Chart with Bento-style Card
            Consumer<SalesDataProvider>(
              builder: (context, provider, child) {
                return SizedBox(
                  height: 200,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SalesChart(salesData: provider.salesData),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Insights and Recommendations
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer<SalesDataProvider>(
                    builder: (context, provider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Insights',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            provider.insights.isNotEmpty
                                ? provider.insights
                                : 'No insights available.',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Recommendations',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            provider.recommendations.isNotEmpty
                                ? provider.recommendations
                                : 'No recommendations available.',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Orders List (Bento-style clean, simple list)
            Expanded(
              child: allOrders.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: allOrders.length,
                      itemBuilder: (context, index) {
                        final order = allOrders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 1,
                          child: ListTile(
                            title: Text(
                              order.orderId,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle:
                                Text('Total Amount: \$${order.totalAmount}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Status: ${order.status}',
                                  style:
                                      const TextStyle(color: Colors.blueAccent),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'cancel') {
                                      _cancelOrder(order.orderId);
                                    } else if (value == 'blacklist') {
                                      _blacklistUser(order.user.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (order.status !=
                                        'Cancelled') // Hide if already cancelled
                                      const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel Order'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'blacklist',
                                      child: Text('Blacklist User'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    OrderDetailsScreen(orderId: order.orderId),
                              ));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderSummation {
  final String period;
  final int amount;

  OrderSummation(this.period, this.amount);

  DateTime? get date {
    try {
      // Attempt to parse period as a year-month (e.g., "2025-03")
      return DateTime.parse('$period-01'); // Assumes period is "YYYY-MM"
    } catch (e) {
      try {
        // Fallback: parse period as a month-year (e.g., "March 2025")
        return DateFormat('MMMM yyyy').parse(period);
      } catch (e) {
        return null; // Return null if parsing fails
      }
    }
  }
}