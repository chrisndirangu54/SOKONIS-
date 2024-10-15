import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'dart:async';

import 'package:grocerry/screens/payment_screen.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> addSubscription(
      Subscription subscription, BuildContext context) async {
    try {
      await _firestore.collection('subscriptions').add(subscription.toMap());
      // After successfully adding the subscription, trigger the payment pop-up
      triggerPaymentPopUp(context, subscription);
    } catch (e) {
      print('Failed to add subscription: $e');
    }
  }

  void triggerPaymentPopUp(BuildContext context, subscription) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Subscription Payment'),
          content: const Text(
              'Would you like to proceed with the payment for your new subscription?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the pop-up
              },
            ),
            ElevatedButton(
              child: const Text('Proceed to Payment'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the pop-up
                // Navigate to payment screen or initiate payment process
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(
                        subscription:
                            subscription), // Replace with your payment screen widget
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Fetch subscriptions by user
  Stream<List<Subscription>> getUserSubscriptions(String user) {
    return _firestore
        .collection('subscriptions')
        .where('user', isEqualTo: user)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Subscription.fromSnapshot(doc))
          .toList();
    });
  }

  // Update next delivery date
  Future<void> updateNextDelivery(
      String subscriptionId, DateTime nextDate) async {
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'nextDelivery': nextDate,
    });
  }

  // Toggle subscription active status
  Future<void> toggleSubscription(String subscriptionId, bool isActive) async {
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'isActive': isActive,
    });
  }

  // Update an existing subscription in Firestore
  void updateSubscription(Subscription updatedSubscription) async {
    await _firestore
        .collection('subscriptions')
        .doc(updatedSubscription as String?)
        .update(updatedSubscription.toMap());
  }

  // Check and deactivate subscriptions after 30 days
  Future<void> deactivateExpiredSubscriptions() async {
    var now = DateTime.now();

    // Fetch subscriptions that need to be deactivated
    var subscriptionsSnapshot = await _firestore
        .collection('subscriptions')
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in subscriptionsSnapshot.docs) {
      Subscription subscription = Subscription.fromSnapshot(doc);

      // Check if the subscription has expired (30 days after activation)
      if (subscription.activationDate
          .add(const Duration(days: 30))
          .isBefore(now)) {
        // Deactivate the subscription
        await _firestore.collection('subscriptions').doc(doc.id).update({
          'isActive': false,
        });

        // Send notification to the customer
        await _sendNotification(subscription.user,
            "Your subscription has been deactivated. Please make a payment to reactivate it.");
      }
    }
  }

  // Send a notification (this can be implemented using a service like Firebase Cloud Messaging)
  Future<void> _sendNotification(String userId, String message) async {
    // Example implementation: this needs to be replaced with your notification logic
    await _firestore.collection('notifications').add({
      'userId': userId,
      'message': message,
      'timestamp': Timestamp.now(),
    });
  }

  // Reactivate subscription upon payment
  Future<void> reactivateSubscription(String subscriptionId) async {
    // Assume payment processing has already occurred
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'isActive': true,
      'activationDate': DateTime.now(), // Reset the activation date
    });

    // Optionally, notify the user about the reactivation
    var subscriptionDoc =
        await _firestore.collection('subscriptions').doc(subscriptionId).get();
    var subscription = Subscription.fromSnapshot(subscriptionDoc);
    await _sendNotification(subscription.user,
        "Your subscription has been reactivated. Thank you for your payment.");
  }

  // Generate a coupon with 10% discount for active subscriptions at the end of the month
  Future<void> generateDiscountCouponForActiveSubscriptions(
      String userId) async {
    // Fetch user subscriptions
    var subscriptionsSnapshot = await _firestore
        .collection('subscriptions')
        .where('user', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    if (subscriptionsSnapshot.docs.isNotEmpty) {
      // If user has an active subscription, generate a coupon
      String couponCode = _generateCouponCode();
      await _firestore.collection('coupons').add({
        'couponCode': couponCode,
        'discountType': 'percentage',
        'discountValue': 10, // 10% discount
        'minimumOrderValue': 0, // No minimum order value
        'expirationDate': Timestamp.fromDate(
          DateTime.now()
              .add(const Duration(days: 30)), // Coupon valid for 30 days
        ),
        'userId': userId, // Track who receives the coupon
        'used': false, // Coupon initially unused
      });
    }
  }

  // Redeem a coupon
  Future<bool> redeemCoupon(String couponCode, String userId) async {
    var couponSnapshot = await _firestore
        .collection('coupons')
        .where('couponCode', isEqualTo: couponCode)
        .where('used', isEqualTo: false)
        .get();

    if (couponSnapshot.docs.isNotEmpty) {
      // Get the coupon document
      var couponDoc = couponSnapshot.docs.first;
      // Update the coupon to mark it as used and associate it with the user
      await couponDoc.reference.update({
        'used': true,
        'redeemedBy': userId, // Track who redeemed the coupon
      });
      return true; // Successful redemption
    }

    return false; // Coupon not found or already used
  }

  // Helper function to generate a random coupon code
  String _generateCouponCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}
