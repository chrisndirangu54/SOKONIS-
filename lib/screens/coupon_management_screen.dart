import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({super.key});

  @override
  CouponManagementScreenState createState() => CouponManagementScreenState();
}

class CouponManagementScreenState extends State<CouponManagementScreen> {
  List<Map<String, dynamic>> allCoupons = [];
  List<Map<String, dynamic>> filteredCoupons = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String searchQuery = '';
  DocumentSnapshot? lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchPaginatedCoupons(); // Fetch first batch of coupons
  }

  // Fetch paginated coupons
  Future<void> _fetchPaginatedCoupons() async {
    if (isLoadingMore) return; // Prevent multiple requests

    setState(() {
      isLoadingMore = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('coupons')
          .orderBy('expirationDate', descending: true)
          .limit(10);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      final QuerySnapshot couponSnapshot = await query.get();

      if (couponSnapshot.docs.isNotEmpty) {
        lastDocument = couponSnapshot.docs.last;
        List<Map<String, dynamic>> newCoupons = couponSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        setState(() {
          allCoupons.addAll(newCoupons);
          filteredCoupons = allCoupons; // Reset filtered coupons
          isLoading = false;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error fetching paginated coupons: $e');
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  // Search filter
  void _filterCoupons(String query) {
    List<Map<String, dynamic>> filtered = allCoupons.where((coupon) {
      final couponName = coupon['name']?.toLowerCase() ?? '';
      final couponCategories =
          (coupon['eligibleCategories'] ?? []).join(", ").toLowerCase();
      return couponName.contains(query.toLowerCase()) ||
          couponCategories.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredCoupons = filtered;
    });
  }

  // Open add coupon dialog
  void _openAddCouponDialog() {
    String? couponName;
    double? discountPercent;
    double? minimumOrderValue;
    double? flatDiscount;
    List<String> requiredProducts = [];
    List<String> eligibleCategories = [];
    List<String> eligibleProducts = [];
    DateTime? expirationDate;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Coupon Name'),
                  onChanged: (value) {
                    couponName = value;
                  },
                ),
                TextField(
                  decoration:
                      const InputDecoration(labelText: 'Discount Percent'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    discountPercent = double.tryParse(value);
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Flat Discount'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    flatDiscount = double.tryParse(value);
                  },
                ),
                TextField(
                  decoration:
                      const InputDecoration(labelText: 'Minimum Order Value'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    minimumOrderValue = double.tryParse(value);
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Required Products (comma-separated)'),
                  onChanged: (value) {
                    requiredProducts =
                        value.split(',').map((e) => e.trim()).toList();
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Eligible Categories (comma-separated)'),
                  onChanged: (value) {
                    eligibleCategories =
                        value.split(',').map((e) => e.trim()).toList();
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Eligible Products (comma-separated)'),
                  onChanged: (value) {
                    eligibleProducts =
                        value.split(',').map((e) => e.trim()).toList();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (couponName != null &&
                    discountPercent != null &&
                    minimumOrderValue != null) {
                  _addCoupon(
                    couponName!,
                    discountPercent!,
                    minimumOrderValue!,
                    flatDiscount,
                    requiredProducts.isEmpty ? null : requiredProducts,
                    eligibleCategories.isEmpty ? null : eligibleCategories,
                    eligibleProducts.isEmpty ? null : eligibleProducts,
                    expirationDate,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Add new coupon to Firestore
  Future<void> _addCoupon(
      String name,
      double discount,
      double minimumOrderValue,
      double? flatDiscount,
      List<String>? requiredProducts,
      List<String>? eligibleCategories,
      List<String>? eligibleProducts,
      DateTime? expirationDate) async {
    try {
      await FirebaseFirestore.instance.collection('coupons').add({
        'name': name,
        'discountPercent': discount,
        'minimumOrderValue': minimumOrderValue,
        'flatDiscount': flatDiscount,
        'requiredProducts': requiredProducts,
        'eligibleCategories': eligibleCategories,
        'eligibleProducts': eligibleProducts,
        'expirationDate': expirationDate,
      });
      _fetchPaginatedCoupons(); // Refresh the list
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      print('Error adding coupon: $e');
    }
  }

  // Check if cart qualifies for a discount
  void _checkForDiscounts(List<String> cartProductIds,
      List<String> cartProductCategories, double cartTotal) {
    for (var coupon in allCoupons) {
      bool qualifies = false;

      // Check minimum order value
      if (cartTotal >= coupon['minimumOrderValue']) {
        qualifies = true;
      }

      // Check required products for combo discount
      List<String> requiredProducts =
          List<String>.from(coupon['requiredProducts'] ?? []);
      if (requiredProducts.isNotEmpty &&
          requiredProducts
              .every((productId) => cartProductIds.contains(productId))) {
        qualifies = true;
      }

      // Check eligible categories
      List<String> eligibleCategories =
          List<String>.from(coupon['eligibleCategories'] ?? []);
      if (eligibleCategories.isNotEmpty &&
          cartProductCategories
              .any((category) => eligibleCategories.contains(category))) {
        qualifies = true;
      }

      // Check eligible products
      List<String> eligibleProducts =
          List<String>.from(coupon['eligibleProducts'] ?? []);
      if (eligibleProducts.isNotEmpty &&
          cartProductIds
              .any((productId) => eligibleProducts.contains(productId))) {
        qualifies = true;
      }

      // Notify user if they qualify
      if (qualifies) {
        String notificationMessage = coupon['flatDiscount'] != null
            ? 'You qualify for a flat discount of ${coupon['flatDiscount']}!'
            : 'You qualify for a ${coupon['discountPercent']}% discount!';

        _showDiscountNotification(notificationMessage);
      }
    }
  }

  void _showDiscountNotification(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green, // Customize background color
      action: SnackBarAction(
        label: 'Close',
        onPressed: () {
          // Optional: Code to execute when the action is pressed
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coupon Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Coupons by Name or Category',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _filterCoupons(searchQuery);
                });
              },
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification.metrics.pixels ==
                    scrollNotification.metrics.maxScrollExtent) {
                  _fetchPaginatedCoupons(); // Load more coupons when scrolled to the bottom
                }
                return true;
              },
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredCoupons.length,
                      itemBuilder: (context, index) {
                        final coupon = filteredCoupons[index];
                        return CouponListItem(coupon: coupon);
                      },
                    ),
            ),
          ),
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddCouponDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CouponListItem extends StatelessWidget {
  final Map<String, dynamic> coupon;

  const CouponListItem({required this.coupon, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(coupon['name'] ?? 'Unnamed Coupon'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coupon['flatDiscount'] != null)
              Text('Flat Discount: ${coupon['flatDiscount']}'),
            if (coupon['discountPercent'] != null)
              Text('Discount: ${coupon['discountPercent']}%'),
            if (coupon['eligibleCategories'] != null &&
                (coupon['eligibleCategories'] as List).isNotEmpty)
              Text(
                  'Eligible Categories: ${(coupon['eligibleCategories'] as List).join(', ')}'),
            if (coupon['eligibleProducts'] != null &&
                (coupon['eligibleProducts'] as List).isNotEmpty)
              Text(
                  'Eligible Products: ${(coupon['eligibleProducts'] as List).join(', ')}'),
          ],
        ),
        onTap: () {
          // Navigate to coupon details or edit page
        },
      ),
    );
  }
}
