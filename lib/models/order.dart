import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/user.dart';

import 'product.dart';

class Order {
  final String orderId;
  late final User user;
  late final String status;
  final List<OrderItem> items;
  String? riderLocation;
  String? riderContact;
  String? estimatedDeliveryTime;
  double totalAmount; // Add price field
  DateTime? date;
  String? address; // Add date field

  Order({
    required this.orderId,
    required this.user,
    required this.status,
    required this.items,
    this.riderLocation,
    this.riderContact,
    this.estimatedDeliveryTime,
    required this.totalAmount,
    this.date,
    required this.address,
  });

  // Factory method to create Order from Firestore
  factory Order.fromFirestore(DocumentSnapshot doc, User user) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
        orderId: doc.id,
        user: data['user'], // Use user object here instead of userId
        status: data['status'],
        items: (data['items'] as List)
            .map((item) => OrderItem.fromMap(item))
            .toList(),
        riderLocation: data['riderLocation'],
        riderContact: data['riderContact'],
        estimatedDeliveryTime: data['estimatedDeliveryTime'],
        totalAmount: data['totalAmount'].toDouble(),
        date: (data['date'] as Timestamp?)?.toDate(),
        address: data['addres']);
  }
  // Method to convert Order object into a Map
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'user': user.toMap(), // Ensure that User has a toMap method
      'status': status,
      'items': items
          .map((item) => item.toMap())
          .toList(), // Convert each item to a map
      'riderLocation': riderLocation,
      'riderContact': riderContact,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'totalAmount': totalAmount,
      'date': date?.toIso8601String(), // Convert DateTime to a String
      'address': address,
    };
  }

  Order copyWith({
    String? status,
    String? riderLocation,
    String? riderContact,
    String? estimatedDeliveryTime,
    DateTime? date,
    String? address,
  }) {
    return Order(
      orderId: orderId,
      user: user, // Keep user unchanged
      status: status ?? this.status,
      items: items,
      riderLocation: riderLocation ?? this.riderLocation,
      riderContact: riderContact ?? this.riderContact,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      totalAmount: totalAmount,
      date: date ?? this.date,
      address: address ?? this.address,
    );
  }
}

class OrderItem {
  final User user;
  final Product product;
  final int quantity;
  final double price; // Link the product directly
  final bool isReviewed;
  final DateTime date;

  OrderItem({
    required this.user,
    required this.product,
    required this.quantity,
    required this.price, // Include price in the constructor
    required this.isReviewed,
    required this.date,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      product: Product.fromMap(
          data['product']), // Assuming you have a similar method for Product
      isReviewed: data['isReviewed'],
      user: data['user'],
      quantity: data['quantity'],
      price: data['price'],
      date: data['date'],
    );
  }
  // Method to convert an OrderItem object into a map
  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(), // Ensure that Product has a toMap method
      'isReviewed': isReviewed,
      'user': user,
      'quantity': quantity,
      'price': price,
      'date': date.toIso8601String(), // Convert DateTime to a String
    };
  }
}
