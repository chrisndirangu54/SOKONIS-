import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/screens/coupon_management_screen.dart';
import 'package:provider/provider.dart';
import 'admin_add_product_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_offers_screen.dart';
import 'pending_deliveries_screen.dart'; // Import for pending deliveries screen
import '../screens/all_orders_screen.dart'; // Import for all orders screen
import '../services/offer_service.dart'; // Import your OfferService

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final OfferService _offerService = OfferService(); // Instance of OfferService
  bool _isWeekendOffersEnabled = true;
  bool _isHolidayOffersEnabled = true;
  List<Product> outOfStockProducts = [];

  @override
  void initState() {
    super.initState();
    // Initialize with the current state of offers (optional if you have saved state)
    _isWeekendOffersEnabled = _offerService.isWeekendOffersEnabled();
    _isHolidayOffersEnabled = _offerService.isHolidayOffersEnabled();
  }

  @override
  Widget build(BuildContext context) {
    // Access the ProductProvider in the build method
    final productProvider = Provider.of<ProductProvider>(context);

    // Load the out-of-stock products
    loadProducts(productProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.orange, // Match your app theme
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Admin Actions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Manage Users Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminUserManagementScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Manage Users'),
            ),
            const SizedBox(height: 20),
            // Add Products Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAddProductScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Add Products'),
            ),
            const SizedBox(height: 20),
            // Create Offers Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminOffersScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Create Offers'),
            ),
            const SizedBox(height: 20),
            // Toggle Weekend Offers Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isWeekendOffersEnabled = !_isWeekendOffersEnabled;
                  if (_isWeekendOffersEnabled) {
                    _offerService.enableWeekendOffers();
                  } else {
                    _offerService.disableWeekendOffers();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: _isWeekendOffersEnabled
                    ? Colors.green
                    : Colors.red, // Toggle color based on state
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(_isWeekendOffersEnabled
                  ? 'Disable Weekend Offers'
                  : 'Enable Weekend Offers'),
            ),
            const SizedBox(height: 20),
            // Toggle Holiday Offers Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isHolidayOffersEnabled = !_isHolidayOffersEnabled;
                  if (_isHolidayOffersEnabled) {
                    _offerService.enableHolidayOffers();
                  } else {
                    _offerService.disableHolidayOffers();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: _isHolidayOffersEnabled
                    ? Colors.green
                    : Colors.red, // Toggle color based on state
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(_isHolidayOffersEnabled
                  ? 'Disable Holiday Offers'
                  : 'Enable Holiday Offers'),
            ),
            const SizedBox(height: 20),
            // Pending Deliveries Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PendingDeliveriesScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Pending Deliveries'),
            ),
            const SizedBox(height: 20),
            // View All Orders Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllOrdersScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('View All Orders'),
            ),
            const SizedBox(height: 20),
            // Coupon Management Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CouponManagementScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Manage Coupons'),
            ),
            const SizedBox(height: 20),
            // View Products Out of Stock Button
            ElevatedButton(
              onPressed: () {
                _showOutOfStockProductsDialog(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('View Products Out of Stock'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void loadProducts(ProductProvider productProvider) {
    // Filter out-of-stock products using the provided isInStock method
    outOfStockProducts = productProvider.products
        .where((product) => !isInStock(product))
        .toList();
  }

  // Method to check if a product is in stock based on quantity
  bool isInStock(Product product) {
    return product.itemQuantity > 0;
  }

  // Dialog to display out-of-stock products
  void _showOutOfStockProductsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Out of Stock Products'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: outOfStockProducts.length,
              itemBuilder: (context, index) {
                final product = outOfStockProducts[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: const Text('Out of stock'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class AdminConversationsScreen extends StatelessWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Conversations with Sentiment Analysis")),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance.collection('conversations').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final conversations = snapshot.data!.docs;
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              var conversation = conversations[index];
              return ListTile(
                title: Text(conversation['message']),
                subtitle: Text(
                  "Sentiment: ${conversation['sentimentScore']}, Sender: ${conversation['sender']}",
                ),
                trailing: Text(conversation['timestamp'].toDate().toString()),
              );
            },
          );
        },
      ),
    );
  }
}
