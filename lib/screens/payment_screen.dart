import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:grocerry/models/user.dart';
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

  late LatLng origin;

  @override
  void initState() {
    super.initState();
    // Initialize origin or fetch it from somewhere appropriate
    origin = LatLng(0, 0); // Replace with actual origin initialization
    isActive = false; // Initialize isActive appropriately
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final User user = userProvider.currentUser;

    // Calculate base price for the subscription
    final basePrice = widget.subscription.price;

    // Calculate the discount amount using CartProvider's method
    final discountAmount = cart.calculateDiscount(_couponCode ?? "", context);
    final totalAfterDiscount = basePrice - discountAmount;

    // Calculate delivery fee and monthly delivery fee
    final Future<double> deliveryFeeFuture = cart.calculateDeliveryFee(
      origin,
      user.pinLocation!,
    ).then((value) => value as double);

    // Define frequency multipliers
    final Map<String, int> frequencyMultipliers = {
      'daily': 30,
      'weekly': 4,
      'monthly': 1,
    };

    // Get the multiplier based on subscription frequency
    final int multiplier = frequencyMultipliers[widget.subscription.frequency] ?? 1;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<double>(
                future: deliveryFeeFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final deliveryFee = snapshot.data!;
                  final monthlyDeliveryFee = deliveryFee * multiplier;
                  final totalWithDelivery = totalAfterDiscount + monthlyDeliveryFee;

                  return SingleChildScrollView(
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
                          style: const TextStyle(fontSize: 18, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Price: \$${basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discount: \$${discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, color: Colors.redAccent),
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
                          'Monthly Delivery Fee (${widget.subscription.frequency}): \$${monthlyDeliveryFee.toStringAsFixed(2)}',
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
                              totalWithDelivery, // Updated to use totalWithDelivery
                              user != null,
                              user.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return const Center(child: Text('Error fetching coupons'));
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
                                      widget.subscription.product as List<Subscription>,
                                      message);

                              setState(() {
                                _isLoading = false;
                              });

                              if (message == "M-Pesa Payment Successful" ||
                                  message == "Visa/MasterCard Payment Successful") {
                                try {
                                  await firestore
                                      .collection('subscriptions')
                                      .doc(subscription)
                                      .update({
                                    'isActive': true, // Update to true on success
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Subscription activated.')),
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Payment successful, but failed to update subscription: $e')),
                                  );
                                }
                              } else {
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
                  );
                },
              ),
      ),
    );
  }
}

// Placeholder for CouponList widget (implement as needed)
class CouponList extends StatelessWidget {
  final List<Map<String, dynamic>> coupons;
  final Function(String) onCouponApplied;

  const CouponList({required this.coupons, required this.onCouponApplied});

  @override
  Widget build(BuildContext context) {
    return Container(); // Replace with actual implementation
  }
}