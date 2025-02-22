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
    // Initialize offer states
    _isWeekendOffersEnabled = _offerService.isWeekendOffersEnabled();
    _isHolidayOffersEnabled = _offerService.isHolidayOffersEnabled();
    // Load products initially (will be updated via Consumer if provider changes)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, child) {
            // Load out-of-stock products when provider updates
            loadProducts(productProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Admin Actions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
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
                    backgroundColor: _isWeekendOffersEnabled ? Colors.green : Colors.red,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(_isWeekendOffersEnabled
                      ? 'Disable Weekend Offers'
                      : 'Enable Weekend Offers'),
                ),
                const SizedBox(height: 20),
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
                    backgroundColor: _isHolidayOffersEnabled ? Colors.green : Colors.red,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(_isHolidayOffersEnabled
                      ? 'Disable Holiday Offers'
                      : 'Enable Holiday Offers'),
                ),
                const SizedBox(height: 20),
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
            );
          },
        ),
      ),
    );
  }

  void loadProducts(ProductProvider productProvider) {
    outOfStockProducts = productProvider.products
        .where((product) => !isInStock(product))
        .toList();
  }

  bool isInStock(Product product) {
    return product.itemQuantity > 0;
  }

  void _showOutOfStockProductsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Out of Stock Products'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5, // Dynamic height
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
      appBar: AppBar(title: const Text("Conversations with Sentiment Analysis")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('conversations').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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

class AudioAnalysis {
  final String id;
  final String audioPath;
  final String sentimentAnalysis;
  final String sabotageInsights;
  final String defamationInsights;
  final Timestamp timestamp;

  AudioAnalysis({
    required this.id,
    required this.audioPath,
    required this.sentimentAnalysis,
    required this.sabotageInsights,
    required this.defamationInsights,
    required this.timestamp,
  });

  factory AudioAnalysis.fromMap(String id, Map<String, dynamic> data) {
    return AudioAnalysis(
      id: id,
      audioPath: data['audioPath'] ?? '',
      sentimentAnalysis: data['sentimentAnalysis'] ?? '',
      sabotageInsights: data['sabotageInsights'] ?? '',
      defamationInsights: data['defamationInsights'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

class AudioAnalysisScreen extends StatefulWidget {
  const AudioAnalysisScreen({super.key});

  @override
  _AudioAnalysisScreenState createState() => _AudioAnalysisScreenState();
}

class _AudioAnalysisScreenState extends State<AudioAnalysisScreen> {
  List<AudioAnalysis> analyses = [];
  bool _isLoading = true; // Add loading state

  Future<void> _fetchAnalyses() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('audio_analyses').get();
    analyses = snapshot.docs.map((doc) => AudioAnalysis.fromMap(doc.id, doc.data())).toList();
    setState(() {
      _isLoading = false; // Update loading state
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Analyses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : analyses.isEmpty
              ? const Center(child: Text('No analyses available'))
              : ListView.builder(
                  itemCount: analyses.length,
                  itemBuilder: (context, index) {
                    final analysis = analyses[index];
                    return _buildAnalysisCard(analysis);
                  },
                ),
    );
  }

  Widget _buildAnalysisCard(AudioAnalysis analysis) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio: ${analysis.audioPath}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Sentiment: ${analysis.sentimentAnalysis}'),
            const SizedBox(height: 10),
            Text('Sabotage Insights: ${analysis.sabotageInsights}'),
            const SizedBox(height: 10),
            Text('Defamation Insights: ${analysis.defamationInsights}'),
            const SizedBox(height: 10),
            Text(
              'Timestamp: ${analysis.timestamp.toDate().toString()}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}