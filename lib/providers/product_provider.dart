import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/services/notification_service.dart';
import 'package:latlong2/latlong.dart' as LatLng;
import '../models/product.dart'; // Import the Product class
import 'package:http/http.dart' as http;

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for real-time product updates
  final StreamController<List<Product>> _productsStreamController =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Product>> _seasonallyAvailableStreamController =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Product>> _nearbyProductsStreamController =
      StreamController<List<Product>>.broadcast();

  final StreamController<List<Product>> _categoryProductsStreamController =
      StreamController<List<Product>>.broadcast(); // Category stream controller

  // Local cache for products
  final List<Product> _products = [];

  final StreamController<List<Product>> _timeOfDayProductsStreamController =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Product>> _weatherProductsStreamController =
      StreamController<List<Product>>.broadcast();

  // Getter for time of day product stream
  Stream<List<Product>> get timeOfDayProductsStream =>
      _timeOfDayProductsStreamController.stream;

  // Getter for weather product stream
  Stream<List<Product>> get weatherProductsStream =>
      _weatherProductsStreamController.stream;

  Product? product;

  // Getter for products
  List<Product> get products => _products;

  Future<List<Product>> fetchNearbyUsersBought() async {
    try {
      User? user;
      LatLng.LatLng? userPinLocation = user!.pinLocation as LatLng.LatLng?;
      double maxDistanceKm = 10.0;
      final querySnapshot = await _firestore
          .collection('products')
          .orderBy('purchaseCount', descending: true)
          .get();

      final List<Product> allProducts = querySnapshot.docs.map((doc) {
        return Product.fromFirestore(doc: doc);
      }).toList();

      // Filter by proximity to mostPurchasedLocation
      final List<Product> nearbyProducts = allProducts.where((product) {
        if (product.mostPurchasedLocation == null) return false;
        return _calculateDistance(
                userPinLocation!, product.mostPurchasedLocation!) <=
            maxDistanceKm;
      }).toList();

      _nearbyProductsStreamController.add(nearbyProducts);
      return nearbyProducts;
    } catch (e) {
      print('Error fetching nearby products: $e');
      _nearbyProductsStreamController.add([]);
      return [];
    }
  }

  double _calculateDistance(LatLng.LatLng point1, LatLng.LatLng point2) {
    const double earthRadius = 6371;
    final double lat1 = point1.latitude * pi / 180;
    final double lon1 = point1.longitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double lon2 = point2.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  // Fetch complementary products for a given product
  List<Product> fetchComplementaryProducts(Product product) {
    if (_products.isEmpty) return [];
    return _products.where((p) => product.isComplementaryTo(p)).toList();
  }

  // Getters for product streams
  Stream<List<Product>> get productsStream => _productsStreamController.stream;
  Stream<List<Product>> get seasonallyAvailableStream =>
      _seasonallyAvailableStreamController.stream;
  Stream<List<Product>> get nearbyUsersBoughtStream =>
      _nearbyProductsStreamController.stream;

  Future<List<Product>> fetchProducts() async {
    try {
      // Fetch products from Firestore
      final querySnapshot = await _firestore.collection('products').get();

      // Map each document to a Product model
      final List<Product> products = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Product.fromFirestore(
            doc: doc); // Make sure fromFirestore handles nulls properly
      }).toList();

      // Ensure the stream controller gets a valid non-null value
      _productsStreamController.add(products);

      return products; // Return the list of products
    } catch (e) {
      // Error occurred, log it and return an empty list to avoid null issues
      print('Error fetching products: $e');

      // Ensure an empty list is returned on error, never null
      _productsStreamController.add([]);

      return []; // Return empty list instead of null
    }
  }

  Future<List<Product>> fetchSeasonallyAvailable() async {
    try {
      // Assuming 'products' is the collection in Firestore where your Product documents are stored
      final querySnapshot = await _firestore.collection('products').get();

      final List<Product> allProducts = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc: doc))
          .toList();

      final currentDate = DateTime.now();
      final seasonallyAvailable = allProducts.where((product) {
        if (!product.isSeasonal) return true;
        if (product.seasonStart != null && product.seasonEnd != null) {
          return currentDate.isAfter(product.seasonStart!) &&
              currentDate.isBefore(product.seasonEnd!);
        }
        return false;
      }).toList();

      _seasonallyAvailableStreamController.add(seasonallyAvailable);
      return seasonallyAvailable; // Ensure a list is returned
    } catch (e) {
      print('Error fetching seasonally available products: $e');
      // You might want to handle the error by sending an empty list or an error signal to the stream.
      _seasonallyAvailableStreamController.add([]);
      return []; // Return an empty list on error
    }
  }

  Future<List<Product>> fetchProductsByName(String name) async {
    try {
      // Query Firestore for products whose name matches or partially matches the given name
      final querySnapshot = await _firestore
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: name)
          .where('name',
              isLessThan: name.substring(0, name.length - 1) +
                  String.fromCharCode(name.codeUnitAt(name.length - 1) + 1))
          .get();

      // Convert Firestore documents to Product objects
      final List<Product> matchingProducts = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc: doc))
          .toList();

      return matchingProducts;
    } catch (e) {
      print('Error fetching products by name: $e');
      return []; // Return an empty list if there's an error to handle it gracefully
    }
  }

  Future<List<Product>> fetchProductsByConsumptionTime() async {
    try {
      // Fetch all products from Firestore
      final querySnapshot = await _firestore.collection('products').get();
      final List<Product> allProducts = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc: doc))
          .toList();

      // Determine current time of day
      final now = DateTime.now();
      final hour = now.hour;
      String consumptionTime;

      // Classify time of day
      if (hour >= 5 && hour < 11) {
        consumptionTime = 'breakfast';
      } else if (hour >= 11 && hour < 17) {
        consumptionTime = 'lunch';
      } else {
        consumptionTime = 'supper';
      }

      // Filter products based on time of day
      final filteredProducts = allProducts.where((product) {
        return product.consumptionTime!.contains(consumptionTime);
      }).toList();

      _timeOfDayProductsStreamController.add(filteredProducts);
      return filteredProducts; // Ensure a list is returned
    } catch (e) {
      print('Error fetching products by time of day: $e');
      _timeOfDayProductsStreamController.add([]); // Send an empty list on error
      return []; // Return an empty list on error
    }
  }

  Future<List<Product>> fetchProductsByWeather() async {
    try {
      // Use Nairobi, KE as an example; replace with user's location if available
      User user = UserProvider().user;
      const apiKey =
          'YOUR_OPENWEATHERMAP_API_KEY'; // Replace with your OpenWeatherMap API key
      var city = user.pinLocation; // Can be dynamic based on user location
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey'));

      if (response.statusCode == 200) {
        final weatherData = jsonDecode(response.body);
        final currentCondition =
            weatherData['weather']?[0]?['description']?.toLowerCase() ??
                'unknown';

        // Fetch all products from Firestore
        final querySnapshot = await _firestore.collection('products').get();
        final List<Product> allProducts = querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc: doc))
            .toList();

        // Determine weather condition and filter products
        String weatherCondition = 'other'; // Default condition
        if (currentCondition.contains('rain') ||
            currentCondition.contains('drizzle')) {
          weatherCondition = 'rainy';
        } else if (currentCondition.contains('cloud') ||
            currentCondition.contains('overcast')) {
          weatherCondition = 'cloudy';
        } else if (currentCondition.contains('clear') ||
            currentCondition.contains('sun')) {
          weatherCondition = 'sunny';
        }

        // Filter products based on weather condition
        final filteredProducts = allProducts.where((product) {
          return product.weather?.contains(weatherCondition) ?? false;
        }).toList();

        _weatherProductsStreamController.add(filteredProducts);
        return filteredProducts; // Return the filtered list
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products by weather: $e');
      _weatherProductsStreamController.add([]); // Send an empty list on error
      return []; // Return an empty list on error
    }
  }

  // Get a single product by its ID from the cached products list
  Product? getProductById(String id) {
    if (_products.isNotEmpty) {
      return _products.firstWhere(
        (product) => product.id == id,
        orElse: () => Product.empty(), // Handle non-existent product
      );
    }
    return null;
  }

  // Method to check if a product is in stock based on quantity
  bool isInStock(Product product) {
    return product.itemQuantity > 0;
  }

  // Method to get the remaining stock for a product
  int getRemainingStock(Product product) {
    return product.itemQuantity;
  }

  Future<Map<String, dynamic>?> getProductDataFromFirestore(
      String productId) async {
    try {
      // Fetch the specific product document from Firestore using productId
      final docSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      // Check if the document exists
      if (docSnapshot.exists) {
        // Assuming you have a Product class to parse Firestore documents
        final product = Product.fromFirestore(doc: docSnapshot);

        // Construct the map with product details
        return {
          'id': product.id, // Product ID
          'name': product.name, // Product Name
          'purchaseCount': product.purchaseCount, // Number of purchases
          'stockLevel': product.itemQuantity, // Current stock level
          'category': product.categories, // Product category
          'seasonStart': product.seasonStart
              ?.toIso8601String(), // Optional: Seasonal start (if applicable)
          'seasonEnd': product.seasonEnd
              ?.toIso8601String(), // Optional: Seasonal end (if applicable)
          'price': product.basePrice, // Price of the product
        };
      } else {
        print('Product with id $productId not found.');
        return null;
      }
    } catch (e) {
      print('Error fetching product data: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _productsStreamController.close();
    _seasonallyAvailableStreamController.close();
    _nearbyProductsStreamController.close();
    _categoryProductsStreamController.close(); // Close category stream
    super.dispose();
  }
}

class StockManager {
  final NotificationService _notificationService;
  late UserProvider _userProvider;

  StockManager(this._notificationService);

  // Method to check if a product is in stock based on quantity and notify isAdmin and isAttendant if out of stock
  bool isInStock(Product product) {
    bool inStock = product.itemQuantity > 0;

    if (!inStock) {
      // Notify both isAdmin and isAttendant that the product is out of stock
      notifyRoles(product);
    }

    return inStock;
  }

  // Method to get the remaining stock for a product
  int getRemainingStock(Product product) {
    return product.itemQuantity;
  }

  // Method to notify admin and attendant if a product is out of stock
  void notifyRoles(Product product) {
    if (_userProvider.user.isAdmin) {
      // Notify Admin
      _notificationService.sendNotification(
        title: 'Product Out of Stock',
        body: 'Product ${product.name} is out of stock.',
        to: _userProvider.user.id,
        data: {},
      );
    }

    if (_userProvider.user.isAttendant) {
      // Notify Attendant
      _notificationService.sendNotification(
        title: 'Product Out of Stock',
        body: 'Product ${product.name} is out of stock.',
        data: {},
        to: _userProvider.user.id,
      );
    }
  }
}
