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
import 'package:grocerry/providers/wallet_provider.dart';
import 'package:grocerry/screens/pending_deliveries_screen.dart';
import 'package:grocerry/services/eta_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:grocerry/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/user.dart' as model;

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  final _cartStreamController =
      StreamController<Map<String, CartItem>>.broadcast();
  Product? product;
  StreamSubscription? _discountedPriceSubscription;
  Stream<double?>? discountedPriceStream2;
  Stream<Map<String, double?>?>? discountedPriceStream;
  final List<Map<String, dynamic>> _pendingOrders = [];

  Map<String, CartItem> get items => _items;

  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;

  Stream<Map<String, CartItem>> get cartStream => _cartStreamController.stream;

  Future<void> addItem(Product product, model.User user,
      Variety? selectedVariety, quantity, notes,
      [status]) async {
    String cartKey =
        '${product.id}_${user.id}'; // Key based on product ID and user ID
    double? priceToUse = await calculatePriceToUse(product, selectedVariety);

    if (_items.containsKey(cartKey)) {
      _items.update(
        cartKey,
        (existingItem) => CartItem(
          user: existingItem.user,
          product: existingItem.product,
          quantity: existingItem.quantity + 1,
          price: priceToUse!,
          notes: notes,
          status: '',
        ),
      );
    } else {
      _items.putIfAbsent(
        cartKey,
        () => CartItem(
            user: user,
            product: product,
            quantity: 1,
            price: priceToUse!,
            notes: null,
            status: ''),
      );
    }
    _cartStreamController.add(_items); // Notify listeners about the cart update
    notifyListeners();
  }

  // Helper method to calculate priceToUse (moved from calculateDiscountsAndUpdateUI)
  Future<double?> calculatePriceToUse(
      Product product, Variety? selectedVariety) async {
    // Handle variety-specific discount price from stream
    if (selectedVariety != null &&
        selectedVariety.discountedPriceStream != null) {
      double? discountedPrice =
          (await selectedVariety.discountedPriceStream!.firstWhere(
        (price) => price != null,
        orElse: () => null,
      )) as double?;
      return discountedPrice ?? selectedVariety.price;
    }
    // Handle variety regular price if no discount stream
    else if (selectedVariety != null) {
      return selectedVariety.price;
    }
    // Handle product-wide discount from stream
    else if (product.hasDiscounts && product.discountedPriceStream2 != null) {
      double? discountedPrice =
          await product.discountedPriceStream2!.firstWhere(
        (price) => price != null,
        orElse: () => null,
      );
      return discountedPrice ?? product.basePrice;
    }
    // Fallback to base price
    else {
      return product.basePrice;
    }
  }

  // Method to remove a product from the cart
  void removeItem(Product product, model.User user) {
    String cartKey =
        '${product.id}_${user.id}'; // Key based on product ID and user ID
    _items.remove(cartKey);
    _cartStreamController.add(_items); // Notify listeners about the cart update
    _pendingOrders.removeWhere((order) => order['productId'] == product.id);
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
  Future<void> updateQuantity(
      product, User user, bool increment, Variety? selectedVariety) async {
    double? priceToUse = await calculatePriceToUse(product, selectedVariety);
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
          price: priceToUse!,
          notes: null,
          status: '',
        ),
      );
      _cartStreamController
          .add(_items); // Notify listeners about the cart update
      notifyListeners();
    }
  }

  // Method to fetch the quantity of a specific item
  int getItemQuantity(Product product, User user) {
    String cartKey = '${product}_$user'; // Key based on product ID and user ID
    if (_items.containsKey(cartKey)) {
      return _items[cartKey]?.quantity ?? 0;
    }
    return 0; // If the item is not in the cart, return 0
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

  model.User? user;

  // Toggle the selection of an item
  void toggleItemSelection(String productId, [Set<String>? selectedItems]) {
    if (selectedItems!.contains(productId)) {
      selectedItems.remove(productId);
    } else {
      selectedItems.add(productId);
    }
    notifyListeners(); // Notify listeners about the change
  }

  Future<void> updateItemNotes(Product product, String? notes) async {
    final CartItem? cartItem = items[product.id];
    if (items.containsKey(product.id)) {
      items[product.id]!.notes = notes;
      // Use the Product's selectedVariety (Variety?) instead of CartItem's selectedVariety (String?)
      items[product.id]!.priceToUse =
          await calculatePriceToUse(product, cartItem!.selectedVariety);
      notifyListeners();
    }
  }

  // Only process the selected items
  void processSelectedItemsCheckout(BuildContext context, selectedItems) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final selectedCartItems = cart.items.values
        .where((item) => selectedItems.contains(item.product.id))
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

  // New method to send order for confirmation with attendant notification
  void sendOrderForConfirmation(BuildContext context, Set<String> selectedItems,
      Function(List<Map<String, dynamic>>) onConfirmationReceived) async {
    final NotificationService notificationService = NotificationService();
    final userProvider = Provider.of<UserProvider>(context,
        listen: false); // Access UserProvider

    // Prepare items for confirmation
    final itemsToConfirm = items.values
        .where((item) => selectedItems.contains(item.product.id))
        .map((item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'notes': item.notes ?? '',
              'status': item.notes != null && item.notes!.isNotEmpty
                  ? 'pending_attendant'
                  : 'confirmed',
              'price': item.price,
            })
        .toList();

    // Determine the attendant ID
    String attendantId;
    if (user != null && user!.isAttendant) {
      // If the current user is an attendant, notify themselves (unlikely scenario)
      attendantId = user!.id;
    } else {
      // Replace with logic to fetch an attendant's ID dynamically
      // For now, using a placeholder or hardcoded value
      attendantId =
          'attendant_user_id'; // Replace with actual attendant ID fetch logic
      // Example: attendantId = userProvider.getAttendantId(); // Hypothetical method
    }

    // Notify the attendant
    try {
      await notificationService.sendNotification(
        to: attendantId, // Use the determined attendant ID (String)
        title: 'Order Confirmation Required',
        body:
            'An order with ${itemsToConfirm.length} items needs your review. Check items with notes.',
        data: {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'action': 'review_order',
          'itemCount': itemsToConfirm.length.toString(),
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to notify attendant: $e')),
      );
    }

    // Invoke the callback with prepared items
    onConfirmationReceived(itemsToConfirm);

    notifyListeners();
  }

  // Method to handle attendant's decision (unchanged from previous)
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
          items[productId]!.status = 'price_adjustment';
          // Optionally, prompt for price adjustment here or elsewhere
          break;
      }
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
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Wallet'),
                onTap: () {
                  Navigator.of(context).pop();
                  _processWalletPayment(selectedItems, context);
                },
              ),
              if (user!.isBlacklisted == false) // Conditionally show COD option
                ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: const Text('Cash on Delivery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _processCODPayment(selectedItems, context);
                  },
                ),
              if (user!.isBlacklisted ==
                  true) // Show error message if user is blacklisted
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Cash on Delivery is not available',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _processWalletPayment(
      List<CartItem> items, BuildContext context) async {
    final totalCost =
        items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (walletProvider.balance >= totalCost) {
      walletProvider.updateBalance(-totalCost); // Deduct from wallet
      _showSuccessDialog('Wallet Payment Successful', items, context);
      return 'Wallet Payment Successful';
    } else {
      _showErrorSnackBar('Insufficient wallet balance.', context);
      return null;
    }
  }

  void _processCODPayment(List<CartItem> items, BuildContext context) async {
    try {
      // Convert cart items to order items
      final List<model.OrderItem> orderItems =
          _convertToOrderItems(items, context);

      // Get the current user
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      // Calculate total amount for the order
      double totalAmount =
          items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

      // Create and add the order to the backend
      final orderProvider =
          Provider.of<model.OrderProvider>(context, listen: false);
      final newOrder = model.Order(
        orderId: DateTime.now().millisecondsSinceEpoch.toString(),
        status: 'Pending Delivery',
        user: user.id,
        totalAmount: totalAmount,
        items: orderItems,
        date: DateTime.now(),
        address: user.address,
        paymentMethod: 'COD',
      );

      orderProvider.addOrder(newOrder);

      // Remove items from the cart after placing the order
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      for (var item in items) {
        cartProvider.removeItem(item.product, user);
      }

      // Show success dialog
      _showSuccessDialog('Cash on Delivery Order Placed', items, context);
    } catch (e) {
      // Log the error for debugging purposes
      print('Error processing COD payment: $e');

      // Show an error message to the user
      _showErrorSnackBar(
          'Failed to place COD order. Please try again.', context);
    }
  }

List<model.OrderItem> _convertToOrderItems(List<CartItem> cartItems, BuildContext context) {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  final user = userProvider.currentUser;

  return cartItems.map((cartItem) => model.OrderItem(
    product: cartItem.product,
    quantity: cartItem.quantity,
    price: cartItem.price,
    notes: cartItem.notes,
    date: DateTime.now(),
    user: user!,
    status: cartItem.status,
  )).toList();
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

  Future<void> savePhoneNumber(String phoneNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedPhoneNumber', phoneNumber);
  }

  Future<String?> getSavedPhoneNumber() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('savedPhoneNumber');
  }

  Future<String?> _processMpesaPayment(List<CartItem> selectedItems,
      BuildContext context, double totalWithDelivery) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    String? phoneNumber = await getSavedPhoneNumber() ?? '2547XXXXXXXX';

    if (phoneNumber == '2547XXXXXXXX') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your phone number'),
          action: SnackBarAction(
            label: 'ADD NUMBER',
            onPressed: () async {
              String? enteredNumber = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Enter Phone Number'),
                  content: TextField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: "07XXXXXXXX"),
                    onChanged: (value) => phoneNumber = value,
                  ),
                  actions: [
                    TextButton(
                      child: const Text('CANCEL'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text('SAVE & OK'),
                      onPressed: () {
                        if (phoneNumber != null && phoneNumber!.length == 10) {
                          Navigator.of(context).pop(phoneNumber);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter a valid 10-digit number')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );

              if (enteredNumber != null) {
                phoneNumber = enteredNumber;
                await savePhoneNumber(phoneNumber!);
                // Recursively call to process payment with new number
                await _processMpesaPayment(
                    selectedItems, context, totalWithDelivery);
              }
            },
          ),
        ),
      );
      return null;
    }

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('initiateMpesaPayment');
      final response = await callable.call({
        'amount': totalWithDelivery,
        'phoneNumber': phoneNumber,
        'paybillNumber': '123456',
        'accountNumber': 'YourAccountNumber',
      });

      if (!context.mounted) return null;

      if (response.data['status'] == 'success') {
        _showSuccessDialog('M-Pesa Payment Initiated', selectedItems, context);

        for (var item in selectedItems) {
          cart.removeItem(item.product, userProvider.currentUser.id);
        }

        return 'M-Pesa Payment Successful';
      } else {
        _showErrorSnackBar('M-Pesa Payment Failed', context);
        return null;
      }
    } catch (e) {
      if (!context.mounted) return null;
      _showErrorSnackBar('M-Pesa Payment Failed', context);
      return null;
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
    final List<model.OrderItem> orderItems = _convertToOrderItems(
        cart.items.values
            .where((item) => _selectedItems.contains(item.product.id))
            .toList(),
        context);

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
                  paymentMethod: '',
                ),
              );

              for (var product in orderedProducts) {

                userProvider.addRecentlyBoughtProduct(product);
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
  const userId = 'your_user_id'; // Replace with dynamic user ID
  final snapshot = await _firestore
      .collection('subscriptions')
      .where('userId', isEqualTo: userId)
      .where('isActive', isEqualTo: true)
      .get();
  final subscriptionFutures =
      snapshot.docs.map((doc) => Subscription.fromSnapshot(doc)).toList();
  return await Future.wait(subscriptionFutures);
}
// In your OrderProvider or wherever you have this method:
  void selectPaymentMethodWithoutCOD(
      List<CartItem> selectedItems, dynamic context) {
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
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Wallet'),
                onTap: () {
                  Navigator.of(context).pop();
                  _processWalletPayment(selectedItems, context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

Future<void> calculateDeliveryFee(LatLng origin, LatLng destination) async {
  try {
    final activeSubscriptions = await _fetchActiveSubscriptions();

    // Check if there's any active subscription with a price of 10,000 or more
    final hasEligibleSubscription = activeSubscriptions.any(
      (subscription) => subscription.price >= 10000, // Now works correctly
    );

    if (hasEligibleSubscription) {
      deliveryFee = 0.0;
      print('Delivery fee: Free (Active subscription with price >= 10000)');
    } else {
      final etaService = ETAService('YOUR_OPENROUTESERVICE_API_KEY');
      final etaAndDistance =
          await etaService.calculateETAAndDistance(origin, destination);

      final distanceInKm = etaAndDistance['distance'] as double;
      deliveryFee = distanceInKm * 40; // $40 per km
      print('Delivery fee: \$${deliveryFee.toStringAsFixed(2)}');
    }

    notifyListeners();
  } catch (e) {
    print('Error calculating delivery fee: $e');
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
        cartItems.map((item) => item.product.categories).toList();

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
      // Use the stored priceToUse
      double itemDiscount =
          (item.product.basePrice - item.priceToUse!) * item.quantity;

      // Accumulate the total discount
      return totalDiscount + itemDiscount;
    });
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

