import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:grocerry/models/order.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/services/notification_service.dart';
import 'dart:math'; // For generating random coupon codes

class OrderProvider with ChangeNotifier {
  final List<Order> _allOrders = [];
  final List<Order> _pendingOrders = [];
  final NotificationService _notificationService = NotificationService();
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;

  // Expose the list of all orders but prevent external modifications
  List<Order> get allOrders => List.unmodifiable(_allOrders);

  // Expose the list of pending orders but prevent external modifications
  List<Order> get pendingOrders => List.unmodifiable(_pendingOrders);

  OrderProvider() {
    _fetchOrdersFromFirebase();
  }

  void updateOrderStatus(String orderId, String newStatus) {
    final orderIndex =
        _allOrders.indexWhere((order) => order.orderId == orderId);

    if (orderIndex != -1) {
      _allOrders[orderIndex].status = newStatus;
      _updatePendingOrders();
      notifyListeners();
      _notifyBackend(orderId, newStatus);
    } else {
      debugPrint('Order with ID $orderId not found.');
    }
  }

  void addOrder(Order newOrder) {
    _allOrders.add(newOrder);
    _updatePendingOrders();
    _notificationService.showOrderNotification(
      'New Order',
      'You have a new order: ${newOrder.orderId}',
    );

    notifyListeners();

    _handleLoyaltyPoints(newOrder.user as String, newOrder.totalAmount);

    // Fetch user's total loyalty points and order count to check for badge eligibility
    _checkAndAwardBadges(
        newOrder.user as String, newOrder.totalAmount, _allOrders.length);

    notifyListeners();

    _handleReferralCoupon(newOrder.user as String, newOrder.totalAmount);
  }

  Future<void> _handleLoyaltyPoints(String user, double orderTotal) async {
    try {
      // Fetch the user's document from Firestore
      final userDoc = await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();

        // Calculate loyalty points (e.g., 1 point per $1 spent)
        int loyaltyPoints = (orderTotal).toInt();

        // Add loyalty points to the user's current points
        int currentPoints = userData?['loyaltyPoints'] ?? 0;
        int updatedPoints = currentPoints + loyaltyPoints;

        // Update the user's points in Firestore
        await firestore.FirebaseFirestore.instance
            .collection('users')
            .doc(user)
            .update({'loyaltyPoints': updatedPoints});

        debugPrint('Loyalty points updated for user: $user');
      }
    } catch (e) {
      debugPrint('Error updating loyalty points: $e');
    }
  }

  void removeOrder(String orderId) {
    final orderIndex =
        _allOrders.indexWhere((order) => order.orderId == orderId);
    if (orderIndex != -1) {
      _allOrders.removeAt(orderIndex);
      _updatePendingOrders();
      notifyListeners();
    } else {
      debugPrint('Order with ID $orderId not found.');
    }
  }

  Future<void> _fetchOrdersFromFirebase() async {
    try {
      final querySnapshot =
          await firestore.FirebaseFirestore.instance.collection('orders').get();
      _allOrders.clear();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final order = Order(
          totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
          riderLocation: data['riderLocation'] ?? 'Unknown location',
          status: data['status'] ?? 'Unknown status',
          date: (data['date'] as firestore.Timestamp?)?.toDate() ??
              DateTime.now(),
          orderId: doc.id,
          items: data['items'] ?? [],
          user: data['User'] ?? 'Unknown user',
          address: data['Address'] ?? 'Unknown Address', paymentMethod: '',
        );
        _allOrders.add(order);
      }
      _updatePendingOrders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
  }

  void _updatePendingOrders() {
    _pendingOrders.clear();
    _pendingOrders.addAll(
      _allOrders.where((order) => order.status == 'Pending'),
    );
  }

  Future<void> _notifyBackend(String orderId, String newStatus) async {
    try {
      await firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});
      debugPrint(
          'Notifying backend: Order $orderId status updated to $newStatus');
    } catch (e) {
      debugPrint('Error notifying backend: $e');
    }
  }

  Map<String, double> getOrderSummations() {
    final now = DateTime.now();
    double dailyTotal = 0;
    double weeklyTotal = 0;
    double monthlyTotal = 0;
    double yearlyTotal = 0;

    for (var order in _allOrders) {
      final orderDate = order.date;
      final orderAmount = order.totalAmount;

      final daysDifference = now.difference(orderDate as DateTime).inDays;
      if (daysDifference < 1) dailyTotal += orderAmount;
      if (daysDifference < 7) weeklyTotal += orderAmount;
      if (daysDifference < 30) monthlyTotal += orderAmount;
      if (daysDifference < 365) yearlyTotal += orderAmount;
    }

    return {
      'Daily': dailyTotal,
      'Weekly': weeklyTotal,
      'Monthly': monthlyTotal,
      'Yearly': yearlyTotal,
    };
  }

  // Updated method to handle referral coupon generation from the user's collection
  Future<void> _handleReferralCoupon(String user, double orderTotal) async {
    try {
      // Fetch the referred user's document from the 'users' collection
      final userDoc = await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();

        // Check if the user has been referred by someone
        final referredBy = userData?['_referredBy'];

        if (referredBy != null && referredBy.isNotEmpty) {
          // Calculate 10% of the order total for the coupon
          final couponValue = orderTotal * 0.10;

          // Generate a referral coupon for the user who referred this one
          await firestore.FirebaseFirestore.instance.collection('coupons').add({
            'couponCode': _generateCouponCode(),
            'discountType': 'flat',
            'discountValue': couponValue,
            'minimumOrderValue': 0, // No minimum since it's a reward
            'expirationDate': firestore.Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 30))),
            'referredUserId':
                user, // Keep track of who triggered the referral coupon
            'referringUserId': referredBy, // The user who referred this user
          });

          debugPrint(
              'Referral coupon generated for user who referred: $referredBy');
        }
      }
    } catch (e) {
      debugPrint('Error generating referral coupon: $e');
    }
  }

  // Helper function to generate a random coupon code
  String _generateCouponCode() {
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
        6, (index) => possible[Random().nextInt(possible.length)]).join();
  }

  Future<void> updateNextDelivery(
      Product product, DateTime nextDate) async {
    await _firestore.collection('subscriptions').doc(product.id).update({
      'nextDelivery': nextDate,
    });
  }

  // Method to check and place replenishment orders
  Future<void> checkAndPlaceReplenishmentOrders(
      dynamic product, dynamic user) async {
    // Fetch all active subscriptions
    final subscriptions = await _fetchActiveSubscriptions();
    for (var subscription in subscriptions) {
      if (_isReplenishmentDue(subscription)) {
        // Create an order for the subscription item
        await _placeReplenishmentOrder(subscription, product, user);
      }
    }
  }

  Future<List<Subscription>> _fetchActiveSubscriptions() async {
    // This method should fetch subscriptions from Firestore (similar to SubscriptionService)
    // Replace 'your_user_id' with the actual user ID
    const user = 'your_user_id';
    final snapshot = await _firestore
        .collection('subscriptions')
        .where('user', isEqualTo: user)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => Subscription.fromSnapshot(doc)).toList();
  }

  bool _isReplenishmentDue(Subscription subscription) {
    // Check if the next delivery date is due
    return DateTime.now().isAfter(subscription.nextDelivery);
  }

  Future<void> _placeReplenishmentOrder(
      Subscription subscription, Product product, dynamic user) async {
    // Retrieve the subscription document from Firestore to check its status
    final subscriptionDoc = await _firestore
        .collection('subscriptions')
        .doc(subscription as String?)
        .get();

    // Check if the subscription is active
    if (subscriptionDoc.exists && subscriptionDoc['isActive'] == true) {
      // Logic to create a list of items for the order
      List<OrderItem> orderItems = [
        OrderItem(
          product: product,
          price: product.basePrice,
          quantity: subscription.quantity,
          user: user.id,
          isReviewed: false,
          date: DateTime.now(),
        )
      ];

      // Create the order
      final order = Order(
        orderId: DateTime.now().millisecondsSinceEpoch.toString(),
        status: 'Pending',
        user: user.id,
        totalAmount: orderItems.fold(
          0,
          (sum, item) => sum + (item.price * item.quantity),
        ),
        items: orderItems,
        date: DateTime.now(),
        address: user.address, paymentMethod: '',
      );

      // Save the order to Firestore
      await _createOrder(order);

      // Update the next delivery date for the subscription
      await updateNextDelivery(
          subscription.product,
          subscription.nextDelivery
              .add(const Duration(days: 7))); // example: replenish weekly

      print('Replenishment order placed successfully.');
    } else {
      print('Subscription is not active; replenishment order not placed.');
    }
  }

  Future<void> _createOrder(Order order) async {
    // This method should save the order to Firestore
    await _firestore.collection('orders').add(order.toMap());
  }

  Future<List<Map<String, dynamic>>> getPastPurchases(String user) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('user', isEqualTo: user)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Error fetching past purchases: $e');
    }
  }

  // Define badge names
  final List<String> badgeNames = ["Moran", "Warrior", "Shujaa", "Mfalme"];

  // Define the number of points required for different coupon values
  final Map<int, double> couponRedemptionValues = {
    100: 5.0, // 100 points can redeem a $5 coupon
    200: 10.0, // 200 points for a $10 coupon
    500: 25.0, // 500 points for a $25 coupon
  };

  // Method to award badges
  Future<void> _awardBadge(String user, String badge) async {
    try {
      // Fetch user's current badges
      final userDoc = await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        List<String> badges = List<String>.from(userData?['badges'] ?? []);

        // Add the badge if not already awarded
        if (!badges.contains(badge)) {
          badges.add(badge);

          // Update badges in Firestore
          await firestore.FirebaseFirestore.instance
              .collection('users')
              .doc(user)
              .update({'badges': badges});

          debugPrint('Badge "$badge" awarded to user: $user');
        }
      }
    } catch (e) {
      debugPrint('Error awarding badge: $e');
    }
  }

  // Method to check and award badges
  Future<void> _checkAndAwardBadges(
      String user, double totalLoyaltyPoints, int totalOrders) async {
    if (totalLoyaltyPoints >= 100) {
      await _awardBadge(user, badgeNames[0]); // Moran
    }
    if (totalOrders >= 5) {
      await _awardBadge(user, badgeNames[1]); // Warrior
    }
    if (totalLoyaltyPoints >= 300) {
      await _awardBadge(user, badgeNames[2]); // Shujaa
    }
    if (totalOrders >= 15) {
      await _awardBadge(user, badgeNames[3]); // Mfalme
    }
  }

  // Method to redeem points and generate a coupon
  Future<void> redeemPointsForCoupon(String user, int pointsToRedeem) async {
    try {
      final userDoc = await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        int currentPoints = userData?['loyaltyPoints'] ?? 0;

        // Check if the user has enough points
        if (currentPoints >= pointsToRedeem &&
            couponRedemptionValues.containsKey(pointsToRedeem)) {
          // Deduct the points
          int updatedPoints = currentPoints - pointsToRedeem;

          // Issue a coupon
          double couponValue = couponRedemptionValues[pointsToRedeem]!;
          await _generateCouponForUser(user, couponValue);

          // Update the user's points in Firestore
          await firestore.FirebaseFirestore.instance
              .collection('users')
              .doc(user)
              .update({'loyaltyPoints': updatedPoints});

          debugPrint('Coupon of value $couponValue issued for user: $user');
        } else {
          debugPrint(
              'Insufficient points or invalid points for coupon redemption.');
        }
      }
    } catch (e) {
      debugPrint('Error redeeming points for coupon: $e');
    }
  }

  // Helper function to generate a coupon for the user
  Future<void> _generateCouponForUser(String user, double couponValue) async {
    try {
      await firestore.FirebaseFirestore.instance.collection('coupons').add({
        'couponCode': _generateCouponCode(),
        'discountType': 'flat',
        'discountValue': couponValue,
        'minimumOrderValue': 0, // No minimum for a loyalty coupon
        'expirationDate': firestore.Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
        'userId': user,
      });
      debugPrint('Coupon generated for user: $user');
    } catch (e) {
      debugPrint('Error generating coupon: $e');
    }
  }
}
