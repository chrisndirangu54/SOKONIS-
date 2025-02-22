import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../providers/user_provider.dart'; // Import UserProvider
import '../providers/product_provider.dart'; // Import ProductProvider
import '../models/product.dart'; // Import the Product class
import '../models/cart_item.dart'; // Import CartItem for cart tracking

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final String _aiApiUrl = 'https://api.openai.com/v1/completions';
  final String _aiApiKey = 'your_openai_api_key_here'; // Replace with your OpenAI API key
  final UserProvider? _userProvider;
  final ProductProvider? _productProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, double> _cartPricesCache = {}; // Cache for tracking cart prices
  DateTime? lastUpdateTime; // Track last update for new products

  NotificationService({
    UserProvider? userProvider,
    ProductProvider? productProvider,
  })  : _userProvider = userProvider,
        _productProvider = productProvider {
    _initializeNotifications();
    if (_userProvider != null && _productProvider != null) {
      _listenToOrderStreams();
      _trackCartItemsForPriceDrop();
    }
    _listenToGeneralStreams();
  }

  // **Initialize Notifications**
  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  // **Listen to General Streams**
  void _listenToGeneralStreams() {
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
      _productProvider!.timeOfDayProductsStream.listen((timeOfDayProducts) {
        _handleTimeOfDayProductUpdates(timeOfDayProducts);
      });
      _productProvider!.weatherProductsStream.listen((weatherProducts) {
        _handleWeatherProductUpdates(weatherProducts);
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

  // **Listen to Order Streams**
  void _listenToOrderStreams() {
    if (_userProvider != null) {
      _userProvider!.cartStream.listen((cartItems, dynamic cartItem) async {
        for (var cartItem in cartItem) {
          final product = _productProvider?.getProductById(cartItem.product.id);
          if (product != null) {
            final currentPrice = product.basePrice;
            if (_cartPricesCache.containsKey(cartItem.product.id) &&
                currentPrice < _cartPricesCache[cartItem.product.id]!) {
              final priceDrop =
                  _cartPricesCache[cartItem.product.id]! - currentPrice;
              _showNotification('Price Drop Alert',
                  'The price of ${product.name} has dropped by \$$priceDrop!');
            }
            _cartPricesCache[cartItem.product.id] = currentPrice;
          }
        }
      } as void Function(Map<String, CartItem> event)?);
    }
  }

  // **Handle Stream Updates**
  Future<void> _handleNewProductUpdates() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  lastUpdateTime ?? DateTime.fromMillisecondsSinceEpoch(0)))
          .orderBy('createdAt', descending: true)
          .get();
      final List<Product> newProducts = querySnapshot.docs.map((doc) {
        return Product.fromFirestore(); // Assuming Product.fromFirestore exists
      }).toList();
      lastUpdateTime = DateTime.now();
      for (var product in newProducts) {
        _analyzeAndNotify(
            product, 'New Product Alert', '${product.name} is now available!');
      }
    } catch (e) {
      print('Error fetching new products: $e');
    }
  }

  void _handleSeasonalProductUpdates(List<Product> seasonalProducts) {
    for (var product in seasonalProducts) {
      _analyzeAndNotify(product, 'Seasonal Product Alert',
          '${product.name} is now in season. Grab it while it lasts!');
    }
  }

  void _handleNearbyUsersBoughtUpdates(List<Product> nearbyProducts) {
    for (var product in nearbyProducts) {
      _analyzeAndNotify(product, 'Trending Nearby',
          'People near you are buying ${product.name}. Check it out!');
    }
  }

  void _handleFavoriteProductUpdates(List<Product> favoriteProducts) {
    for (var product in favoriteProducts) {
      _analyzeAndNotify(product, 'Favorite Product Alert',
          '${product.name} is one of your favorites!');
    }
  }

  void _handleRecentlyBoughtProductUpdates(List<Product> recentlyBought) {
    for (var product in recentlyBought) {
      _analyzeAndNotify(product, 'Recently Bought Update',
          'You recently bought ${product.name}. Check similar products!');
    }
  }

  // **New Handler Methods for Weather and Time of Day**
  void _handleTimeOfDayProductUpdates(List<Product> timeOfDayProducts) {
    for (var product in timeOfDayProducts) {
      _analyzeAndNotify(
        product,
        'Time of Day Alert',
        '${product.name} is perfect for your current time of day!',
      );
    }
  }

  void _handleWeatherProductUpdates(List<Product> weatherProducts) {
    for (var product in weatherProducts) {
      _analyzeAndNotify(
        product,
        'Weather Alert',
        '${product.name} is ideal for today\'s weather!',
      );
    }
  }

  // **Track Cart Items for Price Drops**
  void _trackCartItemsForPriceDrop() {
    _userProvider!.cartStream.listen((cartItems, dynamic cartItem) async {
      for (var cartItem in cartItem) {
        final product = _productProvider!.getProductById(cartItem.product.id);
        if (product != null) {
          final currentPrice = product.basePrice;
          if (_cartPricesCache.containsKey(cartItem.product.id) &&
              currentPrice < _cartPricesCache[cartItem.product.id]!) {
            final priceDrop =
                _cartPricesCache[cartItem.product.id]! - currentPrice;
            _showNotification('Price Drop Alert',
                'The price of ${product.name} has dropped by \$$priceDrop!');
          }
          _cartPricesCache[cartItem.product.id] = currentPrice;
        }
      }
    } as void Function(Map<String, CartItem> event)?);
  }

  // **Fetch Positive Trending Topic**
  Future<String> _fetchPositiveTrendingTopic() async {
    final response = await http.post(
      Uri.parse(_aiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'prompt': 'Provide a short, engaging trending topic in Kenya that has a positive sentiment. '
            'Ensure it does not mention individuals, organizations, politics, or unethical topics. '
            'Format it as a natural attention-grabbing phrase, suitable to blend into a message.',
        'max_tokens': 20,
      }),
    );
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      return result['choices'][0]['text'].trim();
    } else {
      return 'Something exciting is happening in Kenya!'; // Fallback message
    }
  }

  // **Analyze Product with AI**
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
            'Is Complementary: ${product.isComplementary}\n'
            'Weather Suitability: ${product.weather ?? "Not specified"}\n'
            'Time of Day Suitability: ${product.consumptionTime ?? "Not specified"}',
        'max_tokens': 100,
      }),
    );
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      var text = result['choices'][0]['text'];
      return _parseAnalysisResult(text);
    } else {
      throw Exception('Failed to analyze product');
    }
  }

  // **Parse AI Analysis Result**
  Map<String, dynamic> _parseAnalysisResult(String resultText) {
    final lowercasedText = resultText.toLowerCase();
    return {
      'isTrending': lowercasedText.contains('trending'),
      'isComplementary': lowercasedText.contains('complementary'),
      'seasonalHint': lowercasedText.contains('seasonal'),
      'priceDropHint': lowercasedText.contains('price drop'),
    };
  }

  // **Create Personalized Message**
  Future<String> _createPersonalizedMessage(
      String baseMessage, Map<String, dynamic> analysisResult) async {
    String personalizedMessage = baseMessage;
    String trendingTopic = await _fetchPositiveTrendingTopic();
    personalizedMessage = '$trendingTopic $personalizedMessage';
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
      personalizedMessage +=
          ' There has been a recent price drop in this product in your cart!';
    }
    return personalizedMessage;
  }

  // **Analyze and Notify**
  Future<void> _analyzeAndNotify(
      Product product, String title, String baseMessage) async {
    try {
      var analysisResult = await _analyzeProduct(product);
      var personalizedMessage =
          await _createPersonalizedMessage(baseMessage, analysisResult);
      await _showNotification(title, personalizedMessage);
    } catch (e) {
      print('Error analyzing product: $e');
      await _showNotification(title, baseMessage); // Fallback
    }
  }

  // **Show Notification**
  Future<void> _showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('Notifications', 'Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item_payload',
    );
    if (_userProvider != null) {
      final userId = _userProvider!.user.id;
      await storeNotification(
        title: title ?? 'No Title',
        body: body ?? 'No Body',
        userId: userId,
      );
    }
  }

  // **Background Message Handler**
  Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null &&
        notification.title != null &&
        notification.body != null) {
      await _showNotification(notification.title!, notification.body!);
    }
  }

  // **Store Notification in Firestore**
  Future<void> storeNotification({
    required String title,
    required String body,
    required String userId,
    String? orderId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'userId': userId,
        'orderId': orderId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Notification stored successfully.');
    } catch (e) {
      print('Error storing notification: $e');
    }
  }
}