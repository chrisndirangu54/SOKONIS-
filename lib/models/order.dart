import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Order {
  final String orderId;
  late final User user;
  late final String status;
  final List<OrderItem> items;
  LatLng? riderLocation;
  String? riderContact;
  String? estimatedDeliveryTime;
  double totalAmount;
  DateTime? date;
  Address? address;
  String paymentMethod;
  bool isRiderAvailableForDelivery = false; // New property to track rider availability

  Order({
    required this.orderId,
    required this.user,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    this.riderLocation,
    this.riderContact,
    this.estimatedDeliveryTime,
    this.date,
    this.address,
  }) {
    updateRiderDetails();
  }

  void updateRiderDetails() {
    riderLocation = user.liveLocation;
    isRiderAvailableForDelivery = user.isAvailableForDelivery ?? false;
  }

  // If you need to update or set the user after construction:
  void setUser(User user) {
    this.user = user;
    updateRiderDetails(); // Re-evaluate rider details with the new user
  }

  // Constructor or method to update status
  void updateStatus(String newStatus) {
    status = newStatus;
  }

  factory Order.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, User user) {
    final data = doc.data()!;
    return Order(
      orderId: doc.id,
      user: user, // This should be the user passed to the method, not from Firestore
      status: data['status'] ?? 'unknown', // Default status if not provided
      items: List<OrderItem>.from(
          data['items'].map((item) => OrderItem.fromMap(item))),
      riderLocation: data['riderLocation'] != null 
          ? LatLng(data['riderLocation']['latitude'], data['riderLocation']['longitude']) 
          : null,
      riderContact: data['riderContact'],
      estimatedDeliveryTime: data['estimatedDeliveryTime'],
      totalAmount: data['totalAmount'] as double,
      date: (data['date'] as Timestamp?)?.toDate(),
      address: data['address'],
      paymentMethod: data['paymentMethod'] ?? '',
    );
  }

  // Method to convert Order object into a Map
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'user': user.toMap(), // Ensure that User has a toMap method
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'riderLocation': riderLocation != null ? 
          {'latitude': riderLocation!.latitude, 'longitude': riderLocation!.longitude} 
          : null,
      'riderContact': riderContact,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'totalAmount': totalAmount,
      'date': date?.toIso8601String(), // Convert DateTime to a String
      'address': address,
      'paymentMethod': paymentMethod,
    };
  }

  Order copyWith({
    String? status,
    LatLng? riderLocation,
    String? riderContact,
    String? estimatedDeliveryTime,
    DateTime? date,
    Address? address,
  }) {
    return Order(
      orderId: orderId,
      user: user, // User is not changed in copyWith for simplicity
      items: items, // Items are also not changed for simplicity
      status: status ?? this.status,
      totalAmount: totalAmount, // TotalAmount isn't changed in copyWith for simplicity
      paymentMethod: paymentMethod, // PaymentMethod isn't changed in copyWith for simplicity
      riderLocation: riderLocation ?? this.riderLocation,
      riderContact: riderContact ?? this.riderContact,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      date: date ?? this.date,
      address: address ?? this.address,
    );
  }
}

class OrderItem {
  final User user;
  final Product product;
  final int quantity;
  final double price;
  final bool isReviewed;
  final DateTime date;

  String? notes;

  OrderItem({
    required this.user,
    required this.product,
    required this.quantity,
    required this.price,
    this.isReviewed = false,
    required this.date, String? notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      user: data['user'],
      product: Product.fromMap(data['product']),
      quantity: data['quantity'] ?? 0,
      price: data['price'] ?? 0.0,
      isReviewed: data['isReviewed'] ?? false,
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  // Method to convert an OrderItem object into a map
  Map<String, dynamic> toMap() {
    return {
      'user': user.toMap(), // Ensure that User has a toMap method
      'product': product.toMap(), // Ensure that Product has a toMap method
      'quantity': quantity,
      'price': price,
      'isReviewed': isReviewed,
      'date': date.toIso8601String(),
    };
  }
}