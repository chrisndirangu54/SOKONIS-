import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';

class Subscription {
  Product product;
  User user;
  int quantity;
  DateTime nextDelivery;
  bool isActive;
  int frequency;
  Variety variety;
  double price;
  List<Product>? products; // Added to support additional products in updatePrice

  var activationDate;
  var name;

  var status;

  Subscription({
    required this.product,
    required this.user,
    required this.quantity,
    required this.nextDelivery,
    required this.frequency,
    required this.variety,
    this.isActive = true,
    required this.price,
    this.products, // Optional list of additional products
  });
  // Add this factory constructor
  factory Subscription.fromData({
    required Product product,
    required User user,
    required int quantity,
    required DateTime nextDelivery,
    required bool isActive,
    required int frequency,
    required Variety variety,
    required double price,
    List<Product>? products,
  }) {
    return Subscription(
      product: product,
      user: user,
      quantity: quantity,
      nextDelivery: nextDelivery,
      isActive: isActive,
      frequency: frequency,
      variety: variety,
      price: price,
      products: products,
    );
  }

  // Update the price based on the frequency
  void updatePrice() {
    double subPrice = variety.price;

    // Ensure 'price' is initialized, even if with 0.0
    double? price = 0.0;

    switch (frequency) {
      case 1: // Daily
        price = subPrice * quantity * 30; // Approximate 30 days in a month
        break;
      case 7: // Weekly
        price = subPrice * quantity * 4; // 4 weeks in a month
        break;
      case 14: // Bi-weekly
        price = subPrice * quantity * 2; // 2 bi-weekly periods in a month
        break;
      case 30: // Monthly
        price = subPrice * quantity;
        break;
      default:
        price = subPrice * quantity; // If frequency is not set, use monthly as default
    }

    // If there are additional products in the list, add their cost
    if (products != null) {
      for (var p in products!) {
        price = (price ?? 0.0) + p.basePrice * quantity;
            }
    }

    // Ensure that price is not null after this method
    this.price = price!; // Update the class field 'price'
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id, // Store product ID instead of the whole object
      'user': user.id,        // Store user ID instead of the whole object
      'quantity': quantity,
      'nextDelivery': nextDelivery,
      'isActive': isActive,
      'frequency': frequency,
      'price': price,
      'variety': variety.toMap(), // Assuming Variety has a toMap method
      'products': products?.map((p) => p.id).toList(), // Store product IDs if products exist
    };
  }

  // Static async method to fetch data and create Subscription
  static Future<Subscription> fromSnapshot(DocumentSnapshot snapshot) async {
    final data = snapshot.data() as Map<String, dynamic>;
    final productDoc = await FirebaseFirestore.instance
        .collection('products')
        .doc(data['productId'])
        .get();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(data['user'])
        .get();
    final product = Product.fromFirestore(doc: productDoc);
    final user = User.fromJson(userDoc.data()!);
    final variety = Variety.fromMap(data['variety']);
    final products = data['products'] != null
        ? await Future.wait((data['products'] as List).map((id) async {
            final doc = await FirebaseFirestore.instance
                .collection('products')
                .doc(id)
                .get();
            return Product.fromFirestore(doc: doc);
          }))
        : null;

    return Subscription.fromData(
      product: product,
      user: user,
      quantity: data['quantity'] as int,
      nextDelivery: (data['nextDelivery'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
      frequency: data['frequency'] as int,
      price: (data['price'] as num).toDouble(),
      variety: variety,
      products: products,
    );
  }

  // CopyWith method to create a new instance with updated fields
  Subscription copyWith({
    bool? isActive,
    int? quantity,
    int? frequency,
    double? price,
    DateTime? nextDelivery,
    List<Product>? products,
  }) {
    return Subscription(
      isActive: isActive ?? this.isActive,
      quantity: quantity ?? this.quantity,
      frequency: frequency ?? this.frequency,
      user: user,
      product: product,
      nextDelivery: nextDelivery ?? this.nextDelivery,
      price: price ?? this.price,
      variety: variety,
      products: products ?? this.products,
    );
  }
}
