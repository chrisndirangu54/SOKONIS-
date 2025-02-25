import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/screens/coupon_management_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'admin_add_product_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_offers_screen.dart';
import 'pending_deliveries_screen.dart'; // Import for pending deliveries screen
import '../screens/all_orders_screen.dart'; // Import for all orders screen
import '../services/offer_service.dart'; // Import your OfferService

import 'package:fl_chart/fl_chart.dart';

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
                    backgroundColor:
                        _isWeekendOffersEnabled ? Colors.green : Colors.red,
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
                    backgroundColor:
                        _isHolidayOffersEnabled ? Colors.green : Colors.red,
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
      appBar:
          AppBar(title: const Text("Conversations with Sentiment Analysis")),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance.collection('conversations').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
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
    analyses = snapshot.docs
        .map((doc) => AudioAnalysis.fromMap(doc.id, doc.data()))
        .toList();
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

class DashboardScreen extends StatefulWidget {
  final String productId; // Added to make it dynamic

  const DashboardScreen({
    super.key,
    required this.productId,
  });

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Daily'; // Default time period
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sentiment Analysis',
                    style: TextStyle(fontSize: 20)),
                _buildTimePeriodSelector(),
              ],
            ),
            SizedBox(
              height: 300, // Increased height for better visibility
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .doc(widget.productId)
                    .collection('reviews')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviews = snapshot.data!.docs;
                  return _buildSentimentLineChart(reviews);
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text('Validity Analysis', style: TextStyle(fontSize: 20)),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .doc(widget.productId)
                    .collection('reviews')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviews = snapshot.data!.docs;
                  return _buildValidityPieChart(reviews);
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text('Customer Grouping', style: TextStyle(fontSize: 20)),
            _buildCustomerGroups(),
          ],
        ),
      ),
    );
  }

  // Dropdown for selecting time period
  Widget _buildTimePeriodSelector() {
    return DropdownButton<String>(
      value: _selectedPeriod,
      items: ['Daily', 'Weekly', 'Monthly']
          .map((period) => DropdownMenuItem(
                value: period,
                child: Text(period),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedPeriod = value!;
        });
      },
    );
  }

  Widget _buildSentimentLineChart(List<QueryDocumentSnapshot> reviews) {
    // Aggregate data based on the selected time period
    Map<String, Map<String, int>> sentimentByTime = {};

    for (var review in reviews) {
      final timestamp = (review['reviewDate'] as Timestamp).toDate();
      String timeKey;

      // Format the timestamp based on the selected period
      if (_selectedPeriod == 'Daily') {
        timeKey = DateFormat('yyyy-MM-dd').format(timestamp);
      } else if (_selectedPeriod == 'Weekly') {
        final startOfWeek =
            timestamp.subtract(Duration(days: timestamp.weekday - 1));
        timeKey = DateFormat('yyyy-MM-dd').format(startOfWeek);
      } else {
        timeKey = DateFormat('yyyy-MM').format(timestamp);
      }

      sentimentByTime.putIfAbsent(
          timeKey, () => {'positive': 0, 'negative': 0, 'neutral': 0});
      final sentiment = review['sentiment'] as String;
      if (sentiment == 'positive') {
        sentimentByTime[timeKey]!['positive'] =
            sentimentByTime[timeKey]!['positive']! + 1;
      } else if (sentiment == 'negative') {
        sentimentByTime[timeKey]!['negative'] =
            sentimentByTime[timeKey]!['negative']! + 1;
      } else {
        sentimentByTime[timeKey]!['neutral'] =
            sentimentByTime[timeKey]!['neutral']! + 1;
      }
    }

    if (sentimentByTime.isEmpty) {
      return const Center(child: Text('No reviews available'));
    }

    // Sort time keys chronologically
    final sortedKeys = sentimentByTime.keys.toList()..sort();

    // Prepare data for the line chart
    final positiveSpots = <FlSpot>[];
    final negativeSpots = <FlSpot>[];
    final neutralSpots = <FlSpot>[];

    for (int i = 0; i < sortedKeys.length; i++) {
      final timeData = sentimentByTime[sortedKeys[i]]!;
      positiveSpots.add(FlSpot(i.toDouble(), timeData['positive']!.toDouble()));
      negativeSpots.add(FlSpot(i.toDouble(), timeData['negative']!.toDouble()));
      neutralSpots.add(FlSpot(i.toDouble(), timeData['neutral']!.toDouble()));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: positiveSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: negativeSpots,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: neutralSpots,
            isCurved: true,
            color: Colors.grey,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        // Tooltip on touch
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final sentiment = spot.barIndex == 0
                    ? 'Positive'
                    : spot.barIndex == 1
                        ? 'Negative'
                        : 'Neutral';
                return LineTooltipItem(
                  '$sentiment: ${spot.y.toInt()}',
                  TextStyle(
                    color: spot.barIndex == 0
                        ? Colors.green
                        : spot.barIndex == 1
                            ? Colors.red
                            : Colors.grey,
                  ),
                );
              }).toList();
            },
          ),
        ),
        // Titles
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedKeys.length) {
                  return const Text('');
                }
                return Text(
                  sortedKeys[index]
                      .substring(_selectedPeriod == 'Monthly' ? 5 : 5),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade300, strokeWidth: 1),
        ),
        borderData: FlBorderData(
            show: true, border: Border.all(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildValidityPieChart(List<QueryDocumentSnapshot> reviews) {
    int valid = 0, invalid = 0;
    for (var review in reviews) {
      final validity = review['validity'] as String;
      if (validity == 'valid') {
        valid++;
      } else {
        invalid++;
      }
    }

    final total = valid + invalid;
    if (total == 0) {
      return const Center(child: Text('No reviews available'));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: valid.toDouble(),
            color: Colors.blue,
            title: 'Valid\n$valid',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          PieChartSectionData(
            value: invalid.toDouble(),
            color: Colors.orange,
            title: 'Invalid\n$invalid',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildCustomerGroups() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data!.docs;

        final positiveReviews =
            reviews.where((r) => r['sentiment'] == 'positive').toList();
        final negativeReviews =
            reviews.where((r) => r['sentiment'] == 'negative').toList();
        final validReviews =
            reviews.where((r) => r['validity'] == 'valid').toList();
        final invalidReviews =
            reviews.where((r) => r['validity'] == 'invalid').toList();

        return Column(
          children: [
            _buildExpansionTile('Positive Sentiment', positiveReviews),
            _buildExpansionTile('Negative Sentiment', negativeReviews),
            _buildExpansionTile('Valid Reviews', validReviews),
            _buildExpansionTile('Invalid Reviews', invalidReviews),
          ],
        );
      },
    );
  }

// Helper method to build each ExpansionTile with blacklist check
  Widget _buildExpansionTile(
      String title, List<QueryDocumentSnapshot> reviews) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ExpansionTile(title: Text('Loading...'));
        }
        final users = userSnapshot.data!.docs;

        return ExpansionTile(
          title: Text('$title (${reviews.length})'),
          children: reviews.map((r) {
            final reviewerId = r['reviewerId'] as String;
            final userDoc = users.firstWhere(
              (u) => u.id == reviewerId,
              orElse: () => throw Exception('User not found'),
            );
            final isBlacklisted = userDoc['isBlacklisted'] as bool? ?? false;

            return ListTile(
              title: Text('${r['reviewerName']} (ID: $reviewerId)'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review: ${r['reviewText']}'),
                  Text('Response: ${r['autoResponse']}'),
                  if (isBlacklisted)
                    const Text(
                      'Blacklisted',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
