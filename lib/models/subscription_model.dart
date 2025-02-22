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

  var activationDate;

  var name;

  Subscription({
    required this.product,
    required this.user,
    required this.quantity,
    required this.nextDelivery,
    required this.frequency,
    this.isActive = true,
    required this.price, required this.variety,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': product,
      'user': user,
      'quantity': quantity,
      'nextDelivery': nextDelivery,
      'isActive': isActive,
      'price': price,
    };
  }

  factory Subscription.fromSnapshot(DocumentSnapshot snapshot) {
    return Subscription(
      product: snapshot['productId'],
      user: snapshot['user'],
      quantity: snapshot['quantity'],
      nextDelivery: (snapshot['nextDelivery'] as Timestamp).toDate(),
      isActive: snapshot['isActive'],
      frequency: snapshot['frequency'],
      price: snapshot['price'], variety: snapshot['variety'],
    );
  }

  // CopyWith method to create a new instance with updated fields
  Subscription copyWith({
    bool? isActive,
    int? quantity,
    int? frequency,
    double? price,
    required DateTime nextDelivery,
  }) {
    return Subscription(
      isActive: isActive ?? this.isActive,
      quantity: quantity ?? this.quantity,
      frequency: frequency ?? this.frequency,
      user: user,
      product: product,
      nextDelivery: nextDelivery, // Default to 7 days from now
      price: price ?? this.price, variety: variety,
    );
  }
}
