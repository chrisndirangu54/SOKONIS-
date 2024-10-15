import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/providers/cart_provider.dart';
import 'package:grocerry/providers/user_provider.dart';

class PaymentScreen extends StatefulWidget {
  final Subscription subscription;

  PaymentScreen({required this.subscription});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  String? _couponCode;
  bool _isLoading = false;

  String? subscription;
  late bool isActive;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    // Calculate base price for the subscription
    final basePrice = widget.subscription.price;

    // Calculate the discount amount using CartProvider's method
    final discountAmount = cart.calculateDiscount(_couponCode ?? "", context);
    final totalAfterDiscount = basePrice - discountAmount;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Calculate additional service or delivery fee if applicable
    const deliveryFee =
        5.0; // Example fee, you can replace with any other logic
    final totalWithDelivery = totalAfterDiscount + deliveryFee;

    // Calculate the selected total amount for coupon validation
    final selectedTotalAmount = cart.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subscription Details
                    const Text(
                      'Subscription Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Name: ${widget.subscription.name}',
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Price: \$${basePrice.toStringAsFixed(2)}',
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discount: \$${discountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total after Discount: \$${totalAfterDiscount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Service Fee: \$${deliveryFee.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Amount: \$${totalWithDelivery.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Displaying available coupons
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: cart.fetchQualifiedCoupons(
                          cart.items.values.toList(),
                          selectedTotalAmount,
                          user != null,
                          user),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error fetching coupons'));
                        }
                        final coupons = snapshot.data ?? [];
                        return CouponList(
                          coupons: coupons,
                          onCouponApplied: (code) {
                            setState(() {
                              _couponCode = code;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Coupon Input Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter Coupon Code',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (code) {
                        setState(() {
                          _couponCode = code;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Checkout Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _isLoading = true;
                          });

                          // Call CartProvider's method to process subscription payment
                          var message = '';
                          Future<String?> paymentSuccess =
                              cart.processSubscriptionPayment(
                                  context,
                                  widget.subscription.product
                                      as List<Subscription>,
                                  message);

                          setState(() {
                            _isLoading = false;
                          });

                          if (message == "M-Pesa Payment Successful" ||
                              message == "Visa/MasterCard Payment Successful") {
                            // Update subscription status in Firestore
                            try {
                              await firestore
                                  .collection('subscriptions')
                                  .doc(subscription)
                                  .update({
                                'isActive': isActive,
                              });

                              // Show success message and navigate back or to a success screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Subscription activated.')),
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              // Handle Firestore update failure
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Payment successful, but failed to update subscription: $e')),
                              );
                            }
                          } else {
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Payment failed. Please try again.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Proceed to Payment'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 16.0),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
