import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  String product;
  String user;
  int quantity;
  DateTime nextDelivery;
  bool isActive;
  int frequency;

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
    required this.price,
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
      price: snapshot['price'],
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
      user: '',
      product: '',
      nextDelivery: nextDelivery, // Default to 7 days from now
      price: price ?? this.price,
    );
  }
}
