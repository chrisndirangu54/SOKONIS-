import 'dart:async'; // Import the async package
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/order.dart' as model;
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/providers/order_provider.dart' as model;
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/pending_deliveries_screen.dart';
import 'package:grocerry/services/eta_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/user.dart' as model;

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  final _cartStreamController =
      StreamController<Map<String, CartItem>>.broadcast();

  Map<String, CartItem> get items => _items;

  Stream<Map<String, CartItem>> get cartStream => _cartStreamController.stream;

  void addItem(
      Product product, model.User user, Variety? selectedVariety, quantity) {
    String cartKey =
        '${product.id}_${user.id}'; // Key based on product ID and user ID
    double priceToUse;

    if (selectedVariety != null && selectedVariety.discountedPrice != null) {
      priceToUse = selectedVariety.discountedPrice!; // Use the discounted price
    } else if (selectedVariety != null) {
      priceToUse = selectedVariety
          .price; // Use the regular price of the selected variety
    } else if (product.hasDiscounts) {
      priceToUse =
          product.discountedPrice; // Use the product's discounted price
    } else {
      priceToUse = product.basePrice; // Use the base price
    }
    if (_items.containsKey(cartKey)) {
      _items.update(
        cartKey,
        (existingItem) => CartItem(
          user: existingItem.user,
          product: existingItem.product,
          quantity: existingItem.quantity + 1,
          price: priceToUse,
        ),
      );
    } else {
      _items.putIfAbsent(
        cartKey,
        () => CartItem(
            user: user, product: product, quantity: 1, price: priceToUse),
      );
    }
    _cartStreamController.add(_items); // Notify listeners about the cart update
    notifyListeners();
  }

  // Method to remove a product from the cart
  void removeItem(Product product, model.User user) {
    String cartKey =
        '${product.id}_${user.id}'; // Key based on product ID and user ID
    _items.remove(cartKey);
    _cartStreamController.add(_items); // Notify listeners about the cart update
    notifyListeners();
  }

  // Method to get the total amount of the cart
  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  // Method to clear the cart
  void clearCart() {
    _items = {};
    _cartStreamController.add(_items); // Notify listeners about the cart update
    notifyListeners();
  }

  // Method to update the quantity (increment or decrement)
  void updateQuantity(
      product, String user, bool increment, Variety? selectedVariety) {
    double priceToUse;
    if (selectedVariety != null && selectedVariety.discountedPrice != null) {
      priceToUse = selectedVariety.discountedPrice!; // Use the discounted price
    } else if (selectedVariety != null) {
      priceToUse = selectedVariety
          .price; // Use the regular price of the selected variety
    } else if (product.hasDiscounts) {
      priceToUse =
          product.discountedPrice; // Use the product's discounted price
    } else {
      priceToUse = product.basePrice; // Use the base price
    }

    String cartKey = '${product}_$user'; // Key based on product ID and user ID
    if (_items.containsKey(cartKey)) {
      _items.update(
        cartKey,
        (existingItem) => CartItem(
          user: existingItem.user,
          product: existingItem.product,
          quantity: increment
              ? existingItem.quantity + 1
              : (existingItem.quantity > 1 ? existingItem.quantity - 1 : 1),
          price: priceToUse,
        ),
      );
      _cartStreamController
          .add(_items); // Notify listeners about the cart update
      notifyListeners();
    }
  }

  // Method to fetch the quantity of a specific item
  int getItemQuantity(String product, String user) {
    String cartKey = '${product}_$user'; // Key based on product ID and user ID
    if (_items.containsKey(cartKey)) {
      return _items[cartKey]?.quantity ?? 0;
    }
    return 0; // If the item is not in the cart, return 0
  }

  @override
  void dispose() {
    _cartStreamController
        .close(); // Close the StreamController when the provider is disposed
    super.dispose();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // A set to store the IDs of the selected items for checkout
  final Set<String> _selectedItems = {};
  late String customerEmail;
  late String _couponCode;
  late double deliveryFee;
  late double totalWithDelivery;
  late double productDiscounts;
  Set<String> get selectedItems => _selectedItems;

  // Toggle the selection of an item
  void toggleItemSelection(String productId, [Set<String>? _selectedItems]) {
    if (_selectedItems!.contains(productId)) {
      _selectedItems.remove(productId);
    } else {
      _selectedItems.add(productId);
    }
    notifyListeners(); // Notify listeners about the change
  }

  // Only process the selected items
  void processSelectedItemsCheckout(BuildContext context, _selectedItems) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final selectedCartItems = cart.items.values
        .where((item) => _selectedItems.contains(item.product.id))
        .toList();

    if (selectedCartItems.isEmpty) {
      _showErrorSnackBar(
          'Please select at least one item for checkout.', context);
      return;
    }

    _selectPaymentMethod(selectedCartItems, context);
  }

  void _showErrorSnackBar(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> processSubscriptionPayment(
    BuildContext context,
    List<Subscription> selectedSubscriptions,
    String message,
  ) async {
    if (selectedSubscriptions.isEmpty) {
      _showErrorSnackBar(
          'Please select at least one valid subscription for checkout.',
          context);
      return null; // Return null on failure
    }

    try {
      // Assume payment initiation occurs here
      String? paymentMessage;

      // Call the appropriate payment method (Visa/MasterCard or M-Pesa)
      _selectPaymentMethod(selectedSubscriptions.cast<CartItem>(), context);

      // Depending on the user choice, we assume they selected Visa/MasterCard or M-Pesa
      // You'll need logic to capture which one was selected
      // Example:
      paymentMessage = await _processVisaMasterCardPayment(
        selectedSubscriptions.cast<CartItem>(),
        totalWithDelivery,
        context,
      );

      // Or, if M-Pesa was selected:
      paymentMessage = await _processMpesaPayment(
        selectedSubscriptions.cast<CartItem>(),
        context,
        totalWithDelivery,
      );

      if (paymentMessage != null) {
        return paymentMessage; // Return the success message from the payment method
      } else {
        return null; // Return null if payment failed
      }
    } catch (e) {
      _showErrorSnackBar(
          'An error occurred while processing payment: $e', context);
      return null; // Return null on failure
    }
  }

  // Method to show success messages
  void updateItemNotes(Product product, String? notes) {
    if (items.containsKey(product.id)) {
      items[product.id]!.notes = notes;
      notifyListeners();
    }
  }
  // Updated method to show payment methods for selected items
  void _selectPaymentMethod(List<CartItem> selectedItems, dynamic context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Visa/MasterCard'),
                onTap: () {
                  Navigator.of(context).pop();
                  _processVisaMasterCardPayment(
                      selectedItems, totalWithDelivery, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('M-Pesa Paybill'),
                onTap: () {
                  Navigator.of(context).pop();
                  _processMpesaPayment(
                      selectedItems, context, totalWithDelivery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _processVisaMasterCardPayment(List<CartItem> selectedItems,
      double totalWithDelivery, BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FirebaseAuth auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      _showErrorSnackBar('User not logged in.', context);
      return null;
    }

    try {
      // Step 1: Create a Payment Intent in Firestore
      final paymentRef = await firestore
          .collection('customers')
          .doc(currentUser.uid)
          .collection('payments')
          .add({
        'amount': (totalWithDelivery * 100).toInt(), // amount in cents
        'currency': 'usd',
        'status': 'pending',
      });

      final paymentId = paymentRef.id;

      // Step 2: Listen for the client_secret from Firestore
      final paymentSnapshot = await paymentRef.get();
      final clientSecret = paymentSnapshot.data()?['client_secret'];

      if (clientSecret == null) {
        _showErrorSnackBar('Failed to retrieve client secret.', context);
        return null;
      }

      // Step 3: Customize and initialize the Payment Sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Your App Name', // Custom merchant name
          // Additional customizations
        ),
      );

      // Step 4: Present the Payment Sheet
      await stripe.Stripe.instance.presentPaymentSheet();

      // Step 5: Handle payment success
      _showSuccessDialog(
          'Visa/MasterCard Payment Successful', selectedItems, context);

      // Remove items from the cart after successful payment
      for (var item in selectedItems) {
        cart.removeItem(
            item.product.id as Product, userProvider.currentUser.id);
      }

      return 'Visa/MasterCard Payment Successful';
    } catch (e) {
      if (e is stripe.StripeException) {
        _showErrorSnackBar(
            'Payment failed: ${e.error.localizedMessage}', context);
      } else {
        _showErrorSnackBar('Payment Failed', context);
      }
      return null; // Return null on failure
    }
  }

  Future<String?> _processMpesaPayment(List<CartItem> selectedItems,
      BuildContext context, double totalWithDelivery) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('initiateMpesaPayment');
      final response = await callable.call({
        'amount': totalWithDelivery,
        'phoneNumber': '2547XXXXXXXX',
        'paybillNumber': '123456',
        'accountNumber': 'YourAccountNumber',
      });

      if (!context.mounted) return null;

      if (response.data['status'] == 'success') {
        _showSuccessDialog('M-Pesa Payment Initiated', selectedItems, context);

        for (var item in selectedItems) {
          cart.removeItem(
              item.product.id as Product, userProvider.currentUser.id);
        }

        return 'M-Pesa Payment Successful';
      } else {
        _showErrorSnackBar('M-Pesa Payment Failed', context);
        return null; // Return null on failure
      }
    } catch (e) {
      if (!context.mounted) return null;
      _showErrorSnackBar('M-Pesa Payment Failed', context);
      return null; // Return null on failure
    }
  }

  // Updated success dialog to process only selected items
  void _showSuccessDialog(
      String message, List<CartItem> selectedItems, BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    final orderedProducts = selectedItems
        .map((item) => productProvider.getProductById(item.product.id))
        .where((product) => product != null)
        .cast<Product>()
        .toList();

    // Convert selected cart items to order items
    final List<model.OrderItem> orderItems = _convertToOrderItems(cart
        .items.values
        .where((item) => _selectedItems.contains(item.product.id))
        .toList()) as List<model.OrderItem>;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<model.OrderProvider>(context, listen: false).addOrder(
                model.Order(
                  orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                  status: 'Pending',
                  user: user.id,
                  totalAmount: selectedItems.fold(
                    0,
                    (sum, item) => sum + (item.price * item.quantity),
                  ),
                  items: orderItems,
                  date: DateTime.now(),
                  address: user.address,
                ),
              );

              for (var product in orderedProducts) {
                productProvider.updatePurchaseCount(
                  product.id,
                  product.purchaseCount + cart.items[product.id]!.quantity,
                );
                userProvider.addRecentlyBoughtProduct(product.id);
              }

              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const PendingDeliveriesScreen(),
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<List<Subscription>> _fetchActiveSubscriptions() async {
    // This method should fetch subscriptions from Firestore (similar to SubscriptionService)
    // Replace 'your_user_id' with the actual user ID
    const userId = 'your_user_id';
    final snapshot = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => Subscription.fromSnapshot(doc)).toList();
  }

Future<double> calculateDeliveryFee(LatLng origin, LatLng destination) async {
  try {
    final activeSubscriptions = await _fetchActiveSubscriptions();

    // Check if the total price of all active subscriptions is more than 10,000
    final totalSubscriptionPrice = activeSubscriptions.fold<double>(
      0,
      (sum, subscription) => sum + (subscription.price ?? 0),
    );

    if (totalSubscriptionPrice > 10000) {
      print('Delivery fee: Free (Total subscription price > 10000)');
      return 0.0; // If the total price of subscriptions exceeds 10,000, make delivery free
    } else {
      // Proceed with calculating delivery fee based on distance
      final etaService = ETAService('YOUR_GOOGLE_MAPS_API_KEY');
      final etaAndDistance = await etaService.calculateETAAndDistance(origin, destination);

      final distanceInKm = etaAndDistance['distance'] as double;
      final calculatedDeliveryFee = distanceInKm * 40; // $40 per km
      return calculatedDeliveryFee;
    }
  } catch (e) {
    print('Error calculating delivery fee: $e');
    // Return a default value in case of an error
    return 0.0; // Or you could return a different default value or throw an exception
  }
}



  Future<List<Map<String, dynamic>>> fetchQualifiedCoupons(
      List<CartItem> cartItems,
      double cartTotal,
      bool isUserLoggedIn,
      String user) async {
    // Fetch active coupons from Firestore
    final QuerySnapshot couponSnapshot = await _firestore
        .collection('coupons')
        .where('expirationDate',
            isGreaterThan: Timestamp.now()) // Fetch active coupons
        .get();

    List<Map<String, dynamic>> validCoupons = [];

    // Extract product IDs and categories from the cart items
    final cartProductIds = cartItems.map((item) => item.product.id).toList();
    final cartProductCategories =
        cartItems.map((item) => item.product.category).toList();

    for (var doc in couponSnapshot.docs) {
      final couponData = doc.data() as Map<String, dynamic>;

      // Check minimum order value requirement
      final minimumOrderValue = couponData['minimumOrderValue'] ?? 0;
      if (cartTotal >= minimumOrderValue) {
        // Check if coupon is applicable to eligible products
        final eligibleProducts =
            List<String>.from(couponData['eligibleProducts'] ?? []);
        bool isProductEligible = eligibleProducts.isEmpty ||
            cartProductIds.any((id) => eligibleProducts.contains(id));

        // Check if coupon is applicable to eligible categories
        final eligibleCategories =
            List<String>.from(couponData['eligibleCategories'] ?? []);
        bool isCategoryEligible = eligibleCategories.isEmpty ||
            cartProductCategories
                .any((category) => eligibleCategories.contains(category));

        // Check for welcome coupon for new users
        bool isWelcomeCoupon =
            couponData['isWelcomeCoupon'] == true && isUserLoggedIn;

        // Check if the user is eligible for a referral coupon
        bool isReferralCoupon =
            await _checkReferralEligibility(user, couponData);

        // Add coupon if it matches product, category, welcome, or referral coupon eligibility
        if (isProductEligible ||
            isCategoryEligible ||
            isWelcomeCoupon ||
            isReferralCoupon) {
          validCoupons.add(couponData);
        }
      }
    }

    return validCoupons;
  }

  // Helper method to check referral coupon eligibility
  Future<bool> _checkReferralEligibility(
      String userId, Map<String, dynamic> couponData) async {
    // Check if the coupon is a referral coupon
    if (couponData['isReferralCoupon'] == true) {
      try {
        // Query the users collection to find if anyone has been referred by this user
        final QuerySnapshot referredUsersSnapshot = await _firestore
            .collection('users')
            .where('referredBy',
                isEqualTo: userId) // Check if user referred someone
            .get();

        if (referredUsersSnapshot.docs.isNotEmpty) {
          for (var referredUserDoc in referredUsersSnapshot.docs) {
            final referredUserData =
                referredUserDoc.data() as Map<String, dynamic>;

            // Check if the referred user has completed an order or meets other conditions
            final hasCompletedOrder =
                referredUserData['hasCompletedOrder'] == true;

            if (hasCompletedOrder) {
              return true; // The referring user is eligible for a referral coupon
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking referral coupon eligibility: $e');
      }
    }

    return false; // Not eligible if no referred users or conditions aren't met
  }

  // Calculates the discount based on the coupon code
  double calculateDiscount(String couponCode, BuildContext context) {
    if (_couponCode.isEmpty) {
      return 0.0; // No discount if the coupon code is empty
    }

    // Predefined list of valid coupons with discount type (percentage or flat) and values
    const Map<String, Map<String, dynamic>> validCoupons = {
      'SAVE10': {'type': 'percentage', 'value': 0.10}, // 10% discount
      'FLAT50': {'type': 'flat', 'value': 50.0}, // $50 flat discount
      'SAVE20': {'type': 'percentage', 'value': 0.20}, // 20% discount
      'FLAT100': {'type': 'flat', 'value': 100.0}, // $100 flat discount
    };

    final cart = Provider.of<CartProvider>(context, listen: false);

    // Calculate the total amount for selected items
    final totalAmount = cart.items.values
        .where((item) => _selectedItems.contains(item.product.id))
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    // Get coupon data based on the provided coupon code
    final coupon = validCoupons[_couponCode.toUpperCase()];
    if (coupon == null) {
      return 0.0; // No discount if the coupon is not valid
    }

    // Check if the discount is a percentage or a flat amount
    if (coupon['type'] == 'percentage') {
      final discountRate = coupon['value'] as double;
      return totalAmount * discountRate; // Apply percentage discount
    } else if (coupon['type'] == 'flat') {
      final discountAmount = coupon['value'] as double;
      return discountAmount > totalAmount
          ? totalAmount
          : discountAmount; // Flat discount, capped at totalAmount
    }

    return 0.0; // Default case, no discount
  }

  void calculateDiscountsAndUpdateUI(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Calculate product discounts
    productDiscounts = cart.items.values
        .where((item) =>
            _selectedItems.contains(item.product.id)) // Only for selected items
        .fold(0.0, (totalDiscount, item) {
      double priceToUse;

      // Check for variety-specific discount
      if (item.product.selectedVariety != null &&
          item.product.selectedVariety!.discountedPrice != null) {
        priceToUse = item.product.selectedVariety!
            .discountedPrice!; // Use the variety's discounted price
      } else if (item.product.selectedVariety != null) {
        priceToUse = item
            .product.selectedVariety!.price; // Use the variety's regular price
      }
      // Check for product-wide discount
      else if (item.product.hasDiscounts) {
        priceToUse =
            item.product.discountedPrice; // Use the product's discounted price
      } else {
        priceToUse = item.product.basePrice; // Use the product's base price
      }

      // Calculate discount: (Base Price - Price to Use) * Quantity
      double itemDiscount =
          (item.product.basePrice - priceToUse) * item.quantity;

      // Accumulate the total discount
      return totalDiscount + itemDiscount;
    });
  }

    // New method to send order for confirmation
  void sendOrderForConfirmation(BuildContext context, Set<String> selectedItems, Function onConfirmationReceived) {
    final itemsToConfirm = cart.items.values
        .where((item) => selectedItems.contains(item.product.id))
        .map((item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'notes': item.notes,
              'status': 'pending',
              // Add any other necessary data here...
            })
        .toList();

    // Here you'd typically interact with a backend service to send the data.
    // For simplicity, we're simulating this with a local function:
    _simulateBackendConfirmation(itemsToConfirm, onConfirmationReceived);
  }

  // Simulated backend confirmation (replace with actual API call)
  void _simulateBackendConfirmation(List<Map<String, dynamic>> items, Function onConfirmationReceived) {
    Future.delayed(const Duration(seconds: 3), () {
      // Simulated confirmation response from backend
      List<Map<String, dynamic>> confirmedItems = items.map((item) {
        if (item['notes'] != null && item['notes'].isNotEmpty) {
          item['status'] = 'pending_attendant'; // Needs attendant check
        } else {
          item['status'] = 'confirmed'; // No notes, auto-confirm
        }
        return item;
      }).toList();
      onConfirmationReceived(confirmedItems);
    });
  }

  // Method to handle attendant's decision
  void handleAttendantDecision(String productId, String decision) {
    if (items.containsKey(productId)) {
      switch (decision) {
        case 'confirm':
          items[productId]!.status = 'confirmed';
          break;
        case 'decline':
          items[productId]!.status = 'declined';
          break;
        case 'chargeMore':
          // Here you would typically update the price or show a dialog for price adjustment
          items[productId]!.status = 'price_adjustment';
          break;
      }
      notifyListeners();
    }
  }

  // Update processSelectedItemsCheckout method
  void processSelectedItemsCheckout(BuildContext context, Set<String> selectedItems) {
    final itemsToCheckout = cart.items.values
        .where((item) => selectedItems.contains(item.product.id) && item.status == 'confirmed')
        .map((item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'notes': item.notes,
              // other necessary data...
            })
        .toList();
}
}
class CouponInputField extends StatefulWidget {
  final Function(String) onCouponApplied;

  const CouponInputField({super.key, required this.onCouponApplied});

  @override
  CouponInputFieldState createState() => CouponInputFieldState();
}

class CouponInputFieldState extends State<CouponInputField> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: 'Enter Coupon Code',
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            widget.onCouponApplied(_controller.text); // Call the callback
            _controller.clear(); // Clear the input after applying
          },
        ),
      ),
    );
  }
}

class CouponList extends StatelessWidget {
  final List<Map<String, dynamic>> coupons;
  final Function(String) onCouponApplied; // Callback to apply coupon

  const CouponList(
      {super.key, required this.coupons, required this.onCouponApplied});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return ListTile(
          title: Text('${coupon['discountValue']}% off'),
          subtitle: Text('Code: ${coupon['couponCode']}'),
          trailing: ElevatedButton(
            onPressed: () {
              onCouponApplied(
                  coupon['couponCode']); // Apply the coupon using the callback
            },
            child: const Text('Apply'),
          ),
        );
      },
    );
  }
}

class _convertToOrderItems {
  _convertToOrderItems(List<CartItem> list);
}
