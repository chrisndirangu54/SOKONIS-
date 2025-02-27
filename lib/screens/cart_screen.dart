import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/cart_item.dart';

import 'package:grocerry/models/product.dart';

import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/pending_deliveries_screen.dart';

import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  late double productDiscounts;
  final Set<String> _selectedItems = {};
  static const PendingDeliveriesScreen pendingDeliveriesScreen =
      PendingDeliveriesScreen();
  late String _couponCode;

  void _logClick(Product? product, String action) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'click',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
      'action': '',
      'timestamp': DateTime.now(),
    });
  }

  Stream<double?>? _getPriceStream(CartItem cartItem) {
    Variety? selectedVariety = cartItem.selectedVariety != null
        ? cartItem.product.varieties.firstWhere(
            (v) => v.name == cartItem.selectedVariety,
          )
        : cartItem.product.selectedVariety;

    if (selectedVariety != null &&
        selectedVariety.discountedPriceStream != null) {
      // Transform Stream<Map<String, double?>?>? to Stream<double?>?
      return selectedVariety.discountedPriceStream!.map(
        (map) => map != null
            ? map['discountedPrice']
            : null, // Extract double? from map
      );
    } else if (cartItem.product.hasDiscounts &&
        cartItem.product.discountedPriceStream2 != null) {
      // Assuming discountedPriceStream2 is also Stream<Map<String, double?>?>?
      return cartItem.product.discountedPriceStream2!;
    }
    return null; // No stream, use static priceToUse
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final CartItem cartItem = cart.items.values.toList()[0];
    // Calculate total amount for selected items
    final selectedTotalAmount = cart.items.values
        .where((item) => _selectedItems.contains(item.product.id))
        .fold(0.0, (sum, item) => sum! + (item.price * item.quantity));

    // Calculate the discount amount based on the coupon code
    final discountAmount = cart.calculateDiscount(_couponCode, context);
    final totalAfterDiscount = selectedTotalAmount - discountAmount;
    final totalSavings = productDiscounts + discountAmount;
    Product product = cartItem.product;
    // Delivery fee calculation
    LatLng origin = const LatLng(37.7749, -122.4194);
    LatLng destination = user.pinLocation;
    double deliveryFee =
        cart.calculateDeliveryFee(origin, destination) as double;

    // Add delivery fee to the total amount after discount
    final totalWithDelivery = totalAfterDiscount + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_getGreeting()}, ${user?.name ?? 'Guest'}!'),
      ),
      body: Card(
        color: Colors.grey[300], // Set background color to grey[300]
        margin: const EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: cart.items.isEmpty
              ? const Center(
                  child: Text(
                    'Your cart is empty! But it doesn’t have to be. Start adding your favorites and let’s make it full!',
                    style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.items.length,
                        itemBuilder: (ctx, i) {
                          final cartItem = cart.items.values.toList()[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selectedItems
                                        .contains(cartItem.product.id),
                                    onChanged: (_) => cart.toggleItemSelection(
                                        cartItem.product.id, _selectedItems),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cartItem.product.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Quantity: ${cartItem.quantity}',
                                            style:
                                                const TextStyle(fontSize: 16)),
                                        TextField(
                                          decoration: const InputDecoration(
                                            labelText: 'Notes',
                                            hintText: 'e.g., not so ripe',
                                          ),
                                          controller: TextEditingController(
                                              text: cartItem.notes),
                                          onChanged: (value) {
                                            cart.updateItemNotes(
                                                cartItem.product, value);
                                          },
                                        ),
                                        // Add confirmation/rejection buttons if status is 'chargeMore'
                                        if (cartItem.status ==
                                            'price_adjustment') ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              ElevatedButton(
                                                onPressed: () {
                                                  // Confirm the adjusted price
                                                  cart.handleAttendantDecision(
                                                      cartItem.product.id,
                                                      'confirmed');
                                                  setState(() {}); // Update UI
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Price adjustment confirmed')),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green),
                                                child: const Text('Confirm'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  // Reject the adjustment, reset price, and set status to 'declined'
                                                  cart
                                                          .items[cartItem
                                                              .product.id]!
                                                          .price =
                                                      cart.calculatePriceToUse(
                                                              product,
                                                              cartItem.product
                                                                  .selectedVariety)
                                                          as double;
                                                  cart.handleAttendantDecision(
                                                      cartItem.product.id,
                                                      'declined');
                                                  setState(() {}); // Update UI
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Price adjustment rejected, price reset')),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red),
                                                child: const Text('Reject'),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        StreamBuilder<double?>(
                                          stream: _getPriceStream(
                                              cartItem), // Select appropriate stream
                                          initialData: cartItem
                                              .priceToUse, // Start with provider’s default
                                          builder: (context, snapshot) {
                                            final price = snapshot.data ??
                                                cartItem.priceToUse;
                                            return Text(
                                              'Total: \$${(price! * cartItem.quantity).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black54),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.remove_shopping_cart),
                                    color: Colors.red,
                                    onPressed: () {
                                      if (user != null) {
                                        cart.removeItem(
                                            cart.items.keys.toList()[i]
                                                as Product,
                                            user.id);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('User not found.')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total for Selected Items: \$${selectedTotalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Discount: \$${discountAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total after Discount: \$${totalAfterDiscount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Delivery Fee: \$${deliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total with Delivery: \$${totalWithDelivery.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Product Discounts: \$${productDiscounts.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.green),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Savings: \$${totalSavings.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                    // Coupon Input Field
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CouponInputField(onCouponApplied: (code) {
                        setState(() {
                          _couponCode = code;
                        });
                      }),
                    ),
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
                            });
                      },
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: _selectedItems.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (cart.items.values.any((cartItem) =>
                    cartItem.notes != null &&
                    cartItem.notes!.isNotEmpty &&
                    cartItem.status != 'confirmed' &&
                    cartItem.status != 'rejected')) {
                  cart.sendOrderForConfirmation(context, _selectedItems,
                      (List<Map<String, dynamic>> confirmedItems) {
                    setState(() {
                      for (var item in confirmedItems) {
                        cart.handleAttendantDecision(
                            item['productId'], item['status']);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Items sent for confirmation')),
                    );
                  });
                } else {
                  cart.processSelectedItemsCheckout(context, _selectedItems);
                  _logClick(product, 'purchaseCount');
                }
              },
              label: const Text('Confirm/Checkout'),
              icon: const Icon(Icons.payment),
            ),
    );
  }
}
