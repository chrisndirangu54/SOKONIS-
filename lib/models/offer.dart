import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final double price;
  final String productId; // Add productId field
  final double discountedPrice;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.productId, // Initialize productId
    required this.discountedPrice,
  });

  factory Offer.fromFirestore(Map<String, dynamic> data, String id) {
    return Offer(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      startDate: _getDateTime(data['startDate']),
      endDate: _getDateTime(data['endDate'], isEndDate: true),
      price: (data['price'] ?? 0.0).toDouble(),
      productId: data['productId'] ?? '', // Fetch productId
      discountedPrice: (data['discountedPrice'] ?? 0.0).toDouble(),
    );
  }

  static DateTime _getDateTime(dynamic date, {bool isEndDate = false}) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      return DateTime.tryParse(date) ??
          (isEndDate
              ? DateTime.now().add(const Duration(days: 7))
              : DateTime.now());
    }
    return isEndDate
        ? DateTime.now().add(const Duration(days: 7))
        : DateTime.now(); // Fallback
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'startDate': startDate,
      'endDate': endDate,
      'price': price,
      'productId': productId, // Save productId
      'discountedPrice': discountedPrice
    };
  }

  Offer copyWith({required String id}) {
    return Offer(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      startDate: startDate,
      endDate: endDate,
      price: price,
      productId: productId,
      discountedPrice: discountedPrice,
    );
  }
}
