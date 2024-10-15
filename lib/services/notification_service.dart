import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:grocerry/models/cart_item.dart';
import 'package:http/http.dart' as http;
import '../providers/user_provider.dart'; // Import UserProvider
import '../providers/product_provider.dart'; // Import ProductProvider
import '../models/product.dart'; // Import the Product class

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final String _aiApiUrl = 'https://api.openai.com/v1/completions';
  final String _aiApiKey = 'your_openai_api_key_here';

  final UserProvider? _userProvider; // Optional UserProvider
  final ProductProvider? _productProvider; // Optional ProductProvider
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, double> _cartPricesCache =
      {}; // Cache for tracking cart item prices

  NotificationService({
    UserProvider? userProvider,
    ProductProvider? productProvider,
  })  : _userProvider = userProvider,
        _productProvider = productProvider {
    _initializeNotifications();
    if (_userProvider != null && _productProvider != null) {
      _listenToOrderStreams(); // Listen to streams only if providers are available
      _trackCartItemsForPriceDrop(); // Track price drops on cart items
    }
    _listenToGeneralStreams(); // Always listen to general streams
  }

  // Initialize notifications
  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  // Listen to general streams from ProductProvider and UserProvider
  void _listenToGeneralStreams() {
    // Existing stream listeners
    if (_productProvider != null) {
      _productProvider!.productsStream.listen((products) {
        _handleNewProductUpdates();
      });

      _productProvider!.seasonallyAvailableStream.listen((seasonalProducts) {
        _handleSeasonalProductUpdates(seasonalProducts);
      });

      _productProvider!.nearbyUsersBoughtStream.listen((nearbyProducts) {
        _handleNearbyUsersBoughtUpdates(nearbyProducts);
      });
    }

    if (_userProvider != null) {
      _userProvider!.favoritesStream.listen((favorites) {
        _handleFavoriteProductUpdates(favorites);
      });

      _userProvider!.recentlyBoughtStream.listen((recentlyBought) {
        _handleRecentlyBoughtProductUpdates(recentlyBought);
      });
    }
  }

  // Listen to order-related streams and track cart items
  void _listenToOrderStreams() {
    if (_userProvider != null) {
      _userProvider!.cartStream.listen((cartItems, dynamic cartItem) async {
        for (var cartItem in cartItem) {
          final product = _productProvider?.getProductById(cartItem.product.id);
          if (product != null) {
            final currentPrice = product.basePrice;

            // Check if the price has dropped
            if (_cartPricesCache.containsKey(cartItem.product.id) &&
                currentPrice < _cartPricesCache[cartItem.product.id]!) {
              final priceDrop =
                  _cartPricesCache[cartItem.product.id]! - currentPrice;
              _showNotification('Price Drop Alert',
                  'The price of ${product.name} has dropped by \$$priceDrop!');
            }

            // Update the price in the cache
            _cartPricesCache[cartItem.product.id] = currentPrice;
          }
        }
      } as void Function(Map<String, CartItem> event)?);
    }
  }

  var lastUpdateTime;

  void _handleNewProductUpdates() async {
    try {
      // Determine the query start time
      final Timestamp startTime = lastUpdateTime != null
          ? Timestamp.fromDate(lastUpdateTime!)
          : Timestamp.fromMillisecondsSinceEpoch(0);

      // Fetch products created since the last update
      final querySnapshot = await _firestore
          .collection('products')
          .where('createdAt', isGreaterThan: startTime)
          .orderBy('createdAt', descending: true)
          .get();

      final List<Product> newProducts = querySnapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();

      // Update the last update time to now
      lastUpdateTime = DateTime.now();

      // Process new products
      for (var product in newProducts) {
        _analyzeAndNotify(
            product, 'New Product Alert', '${product.name} is now available!');
      }
    } catch (e) {
      print('Error fetching new products: $e');
    }
  }

  // Handle seasonal product updates
  void _handleSeasonalProductUpdates(List<Product> seasonalProducts) {
    for (var product in seasonalProducts) {
      _analyzeAndNotify(product, 'Seasonal Product Alert',
          '${product.name} is now in season. Grab it while it lasts!');
    }
  }

  // Handle nearby users' bought product updates
  void _handleNearbyUsersBoughtUpdates(List<Product> nearbyProducts) {
    for (var product in nearbyProducts) {
      _analyzeAndNotify(product, 'Trending Nearby',
          'People near you are buying ${product.name}. Check it out!');
    }
  }

  // Handle favorite product updates
  void _handleFavoriteProductUpdates(List<Product> favoriteProducts) {
    for (var product in favoriteProducts) {
      _analyzeAndNotify(product, 'Favorite Product Alert',
          '${product.name} is one of your favorites!');
    }
  }

  // Handle recently bought product updates
  void _handleRecentlyBoughtProductUpdates(List<Product> recentlyBought) {
    for (var product in recentlyBought) {
      _analyzeAndNotify(product, 'Recently Bought Update',
          'You recently bought ${product.name}. Check similar products!');
    }
  }

  // Track cart items for price drop notifications
  void _trackCartItemsForPriceDrop() {
    _userProvider!.cartStream.listen((cartItems, dynamic cartItem) async {
      for (var cartItem in cartItem) {
        final product = _productProvider!.getProductById(cartItem.product.id);
        if (product != null) {
          final currentPrice = product.basePrice;

          // Check if the price has dropped
          if (_cartPricesCache.containsKey(cartItem.product.id) &&
              currentPrice < _cartPricesCache[cartItem.product.id]!) {
            final priceDrop =
                _cartPricesCache[cartItem.product.id]! - currentPrice;
            _showNotification('Price Drop Alert',
                'The price of ${product.name} has dropped by \$$priceDrop!');
          }

          // Update the price in the cache
          _cartPricesCache[cartItem.product.id] = currentPrice;
        }
      }
    } as void Function(Map<String, CartItem> event)?);
  }

  // Analyze product using AI and send personalized notifications
  Future<void> _analyzeAndNotify(
      Product product, String title, String baseMessage) async {
    try {
      var analysisResult = await _analyzeProduct(product);
      var personalizedMessage =
          _createPersonalizedMessage(baseMessage, analysisResult);
      _showNotification(title, personalizedMessage);
    } catch (e) {
      print('Error analyzing product: $e');
      _showNotification(title, baseMessage); // Fallback to default message
    }
  }

  // Analyze product data using OpenAI API
  Future<Map<String, dynamic>> _analyzeProduct(Product product) async {
    final response = await http.post(
      Uri.parse(_aiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey',
      },
      body: jsonEncode({
        'model': 'text-davinci-003',
        'prompt': 'Analyze the following product data and provide insights:\n'
            'Product: ${product.name}\n'
            'Price: ${product.basePrice}\n'
            'Is Seasonal: ${product.isSeasonal}\n'
            'Is Trending: ${product.isTrending}\n'
            'Is Complementary: ${product.isComplementary}',
        'max_tokens': 100,
      }),
    );

    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      var text = result['choices'][0]['text'] as String;
      return _parseAnalysisResult(text);
    } else {
      throw Exception('Failed to analyze product');
    }
  }

  // Parse the AI analysis result
  Map<String, dynamic> _parseAnalysisResult(String resultText) {
    final lowercasedText = resultText.toLowerCase();
    return {
      'isTrending': lowercasedText.contains('trending'),
      'isComplementary': lowercasedText.contains('complementary'),
      'seasonalHint': lowercasedText.contains('seasonal'),
      'priceDropHint': lowercasedText.contains('price drop'),
    };
  }

  // Create a personalized message based on AI analysis and base message
  String _createPersonalizedMessage(
      String baseMessage, Map<String, dynamic> analysisResult) {
    String personalizedMessage = baseMessage;

    if (analysisResult['isTrending']) {
      personalizedMessage += ' It\'s trending right now!';
    }
    if (analysisResult['isComplementary']) {
      personalizedMessage += ' It complements your recent purchases.';
    }
    if (analysisResult['seasonalHint']) {
      personalizedMessage += ' This item is perfect for the current season!';
    }
    if (analysisResult['priceDropHint']) {
      personalizedMessage += ' There has been a recent price drop!';
    }

    return personalizedMessage;
  }

  // Show notification and store it in Firestore
  Future<void> _showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('Notifications', 'Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show the notification locally
    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item_payload',
    );

    // Call storeNotification to save it in Firestore
    if (_userProvider != null) {
      final userId = _userProvider!.user.id; // Assuming you have a user id

      await storeNotification(
        title: title ?? 'No Title',
        body: body ?? 'No Body',
        userId: userId, // Use the current user's id
      );
    }
  }

  // Handle background messages (for Firebase notifications)
  Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null &&
        notification.title != null &&
        notification.body != null) {
      await _showNotification(notification.title!, notification.body!);
    }
  }

  // Method to show notifications related to orders and store them in Firestore
  Future<void> showOrderNotification(String title, String body) async {
    // Check if _userProvider and _productProvider are not null
    if (_userProvider != null && _productProvider != null) {
      // Check if the user is an attendant or a rider
      final user = _userProvider?.user;
      if (user != null && (user.isAttendant || user.isRider)) {
        // Show the notification
        await _showNotification(title, body);

        // Store the notification in Firestore
        await storeNotification(
          title: title,
          body: body,
          userId: user.id, // Store the notification under the current user's ID
          orderId: null, // You can pass the orderId if it's relevant
        );
      } else {
        print(
            'User is neither an attendant nor a rider, or user data is not available. Notification not shown.');
      }
    } else {
      print(
          'UserProvider and ProductProvider must be provided for order notifications.');
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      // Assuming you store notifications in a 'notifications' collection in Firestore
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId',
              isEqualTo: _userProvider?.user.uid) // Optional filter by user ID
          .orderBy('timestamp',
              descending: true) // Assuming you store timestamps
          .get();

      // Map Firestore docs to a list of notifications
      final List<Map<String, dynamic>> notifications =
          querySnapshot.docs.map((doc) {
        return {
          'title': doc['title'],
          'body': doc['body'],
          'timestamp': doc['timestamp'],
          // Add other fields as needed
        };
      }).toList();

      return notifications;
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

    Future<void> showReplenishmentReminder(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('replenishment_channel', 'Replenishment Notifications',
            channelDescription: 'Notification channel for replenishment reminders',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }


  Future<void> storeNotification({
    required String title,
    required String body,
    required String userId, // Assuming you want to store notifications per user
    String? orderId, // Optional: can be used for order-related notifications
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'userId': userId,
        'orderId': orderId, // If applicable
        'timestamp': FieldValue.serverTimestamp(), // Auto-generate timestamp
      });
      print('Notification stored successfully.');
    } catch (e) {
      print('Error storing notification: $e');
    }
  }
}
