import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/services/notification_service.dart';
import '../models/product.dart'; // Import the Product class

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for real-time product updates
  final StreamController<List<Product>> _productsStreamController =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Product>> _seasonallyAvailableStreamController =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Product>> _nearbyUsersBoughtStreamController =
      StreamController<List<Product>>.broadcast();

  final StreamController<List<Product>> _categoryProductsStreamController =
      StreamController<List<Product>>.broadcast(); // Category stream controller

  // Local cache for products
  final List<Product> _products = [];

  // Getter for products
  List<Product> get products => _products;

  Future<void> fetchNearbyUsersBought() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .orderBy('purchaseCount', descending: true)
          .limit(10)
          .get();

      // Convert documents to products
      final List<Product> nearbyUsersBought =
          querySnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      // Add the list of products to the stream controller
      _nearbyUsersBoughtStreamController.add(nearbyUsersBought);
    } catch (e) {
      print('Error fetching nearby users bought products: $e');
      // You might want to add an empty list or an error state to the stream
      _nearbyUsersBoughtStreamController.add([]);
    }
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
      _nearbyUsersBoughtStreamController.stream;

  Stream<List<Product>> get categoryProductsStream =>
      _categoryProductsStreamController.stream;

  Future<List<Product>> fetchProducts() async {
    try {
      final querySnapshot = await _firestore.collection('products').get();
      final List<Product> products =
          querySnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      // Add the list of products to the stream controller
      _productsStreamController.add(products);

      // Return the list of products
      return products; // Ensure you return the list of products
    } catch (e) {
      print('Error fetching products: $e');
      // Add an empty list in case of an error
      _productsStreamController.add([]);
      return []; // Ensure you return an empty list to satisfy the return type
    }
  }


  // Update the purchase count of a product in Firestore
  Future<void> updatePurchaseCount(
      String productId, int newPurchaseCount) async {
    try {
      // Reference to the specific product document in Firestore
      final productDoc = _firestore.collection('products').doc(productId);

      // Update the 'purchaseCount' field in the Firestore document
      await productDoc.update({
        'purchaseCount': newPurchaseCount,
      });

      // Optionally, you can also update the cached product
      final productIndex =
          _products.indexWhere((product) => product.id == productId);
      if (productIndex != -1) {
        _products[productIndex].purchaseCount = newPurchaseCount;
        _productsStreamController.add(_products); // Update the product stream
      }

      print('Purchase count updated successfully for product: $productId');
    } catch (e) {
      print('Error updating purchase count: $e');
    }
  }

  // Real-time Firestore stream for category-based products
  Future<void> fetchCategoryProducts(String category) async {
    try {
      _firestore
          .collection('products')
          .where('category', isEqualTo: category)
          .snapshots()
          .listen((querySnapshot) {
        final categoryProducts = querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
        _categoryProductsStreamController.add(categoryProducts);
      });
    } catch (e) {
      print("Error fetching products by category: $e");
      _categoryProductsStreamController.add([]);
    }
  }

  Future<void> fetchSeasonallyAvailable() async {
    try {
      // Assuming 'products' is the collection in Firestore where your Product documents are stored
      final querySnapshot = await _firestore.collection('products').get();

      final List<Product> allProducts =
          querySnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

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
    } catch (e) {
      print('Error fetching seasonally available products: $e');
      // You might want to handle the error by sending an empty list or an error signal to the stream.
      _seasonallyAvailableStreamController.add([]);
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
        final product = Product.fromFirestore(docSnapshot);

        // Construct the map with product details
        return {
          'id': product.id, // Product ID
          'name': product.name, // Product Name
          'purchaseCount': product.purchaseCount, // Number of purchases
          'stockLevel': product.itemQuantity, // Current stock level
          'category': product.category, // Product category
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
    _nearbyUsersBoughtStreamController.close();
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
      _notificationService._showNotification(
        title: 'Product Out of Stock',
        body: 'Product ${product.name} is out of stock.',
      );
    }

    if (_userProvider.user.isAttendant) {
      // Notify Attendant
      _notificationService._showNotification(
        title: 'Product Out of Stock',
        body: 'Product ${product.name} is out of stock.',
      );
    }
  }
}

extension on NotificationService {
  void _showNotification({required String title, required String body}) {}
}
