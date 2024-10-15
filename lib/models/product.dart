import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double basePrice;
  final String description;
  late final String category;
  final String units;
  final String categoryImageUrl; // New field for category image URL
  final List<String> subcategories; // New field for subcategories
  final List<String>
      subcategoryImageUrls; // New field for subcategory image URLs
  final List<Variety>
      varieties; // New field for custom varieties (color, size, etc.)
  final List<String> varietyImageUrls;
  final String pictureUrl;
  final DateTime? lastPurchaseDate;
  final bool isComplementary;
  final List<String> complementaryProductIds;
  final bool isSeasonal;
  final DateTime? seasonStart;
  final DateTime? seasonEnd;

  int purchaseCount;
  int recentPurchaseCount;
  int reviewCount;
  int itemQuantity;
  int views;
  int clicks;
  int favorites;
  int timeSpent;

  // New fields
  final bool isFresh;
  final bool isLocallySourced;
  final bool isOrganic;
  final bool hasHealthBenefits;
  final bool hasDiscounts;
  final double discountedPrice;
  final bool isEcoFriendly;
  final bool isSuperfood;

  late int userViews;
  late int userTimeSpent;

  Product({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.description,
    required this.category,
    required this.categoryImageUrl, // Initialize new field
    required this.units,
    this.subcategories = const [], // Initialize new field
    this.subcategoryImageUrls = const [], // Initialize new field
    this.varieties = const [], // Initialize new field
    this.varietyImageUrls = const [],
    required this.pictureUrl,
    this.lastPurchaseDate,
    this.isComplementary = false,
    this.complementaryProductIds = const [],
    this.isSeasonal = false,
    this.seasonStart,
    this.seasonEnd,
    this.purchaseCount = 0,
    this.recentPurchaseCount = 0,
    this.reviewCount = 0,
    this.itemQuantity = 0,
    this.views = 0,
    this.clicks = 0,
    this.favorites = 0,
    this.timeSpent = 0,
    this.isFresh = false,
    this.isLocallySourced = false,
    this.isOrganic = false,
    this.hasHealthBenefits = false,
    this.hasDiscounts = false,
    required this.discountedPrice,
    this.isEcoFriendly = false,
    this.isSuperfood = false,
  });

  // Factory constructor to create a Product instance from Firestore data
  factory Product.fromFirestore(DocumentSnapshot doc, [String? id]) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely parsing price in case it is not a double
    final basePrice = data['basePrice'] is int
        ? (data['basePrice'] as int).toDouble()
        : data['basePrice'];

    return Product(
      id: doc.id,
      name: data['name'],
      basePrice: basePrice,
      description: data['description'],
      category: data['category'],
      categoryImageUrl: data['categoryImageUrl'], // Parse new field
      subcategories:
          List<String>.from(data['subcategories'] ?? []), // Parse new field
      subcategoryImageUrls: List<String>.from(
          data['subcategoryImageUrls'] ?? []), // Parse new field
      varieties: (data['varieties'] as List<dynamic>? ?? [])
          .map((v) => Variety.fromMap(v))
          .toList(), // Parse new field
      varietyImageUrls: List<String>.from(data['varietyImageUrls'] ?? []),
      pictureUrl: data['pictureUrl'],
      lastPurchaseDate: data['lastPurchaseDate'] != null
          ? (data['lastPurchaseDate'] as Timestamp).toDate()
          : null,
      complementaryProductIds:
          List<String>.from(data['complementaryProductIds'] ?? []),
      isSeasonal: data['isSeasonal'] ?? false,
      seasonStart: data['seasonStart'] != null
          ? (data['seasonStart'] as Timestamp).toDate()
          : null,
      seasonEnd: data['seasonEnd'] != null
          ? (data['seasonEnd'] as Timestamp).toDate()
          : null,
      purchaseCount: data['purchaseCount'] ?? 0,
      recentPurchaseCount: data['recentPurchaseCount'] ?? 0,
      reviewCount: data['reviewCount'] ?? 0,
      itemQuantity: data['itemQuantity'] ?? 0,
      views: data['views'] ?? 0,
      clicks: data['clicks'] ?? 0,
      favorites: data['favorites'] ?? 0,
      timeSpent: data['timeSpent'] ?? 0,
      isFresh: data['isFresh'] ?? false,
      isLocallySourced: data['isLocallySourced'] ?? false,
      isOrganic: data['isOrganic'] ?? false,
      hasHealthBenefits: data['hasHealthBenefits'] ?? false,
      hasDiscounts: data['hasDiscounts'] ?? false,
      isEcoFriendly: data['isEcoFriendly'] ?? false,
      isSuperfood: data['isSuperfood'] ?? false,
      discountedPrice: data['discountedPrice'],
      units: data['units'],
    );
  }

  // Convert Product instance to a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'basPrice': basePrice,
      'description': description,
      'category': category,
      'categoryImageUrl': categoryImageUrl, // Include new field
      'subcategories': subcategories, // Include new field
      'subcategoryImageUrls': subcategoryImageUrls, // Include new field
      'varieties':
          varieties.map((v) => v.toMap()).toList(), // Include new field
      'varietyImageUrls': varietyImageUrls,
      'pictureUrl': pictureUrl,
      'lastPurchaseDate': lastPurchaseDate?.toIso8601String(),
      'complementaryProductIds': complementaryProductIds,
      'isSeasonal': isSeasonal,
      'seasonStart': seasonStart?.toIso8601String(),
      'seasonEnd': seasonEnd?.toIso8601String(),
      'purchaseCount': purchaseCount,
      'recentPurchaseCount': recentPurchaseCount,
      'reviewCount': reviewCount,
      'itemQuantity': itemQuantity,
      'views': views,
      'clicks': clicks,
      'favorites': favorites,
      'timeSpent': timeSpent,
      'isFresh': isFresh,
      'isLocallySourced': isLocallySourced,
      'isOrganic': isOrganic,
      'hasHealthBenefits': hasHealthBenefits,
      'hasDiscounts': hasDiscounts,
      'isEcoFriendly': isEcoFriendly,
      'isSuperfood': isSuperfood,
    };
  }

  // Method to check if the product is in season
  bool isInSeason() {
    if (!isSeasonal) return true;
    final now = DateTime.now();
    return (seasonStart?.isBefore(now) ?? false) &&
        (seasonEnd?.isAfter(now) ?? false);
  }

  // Method to check if this product is complementary to another product
  bool isComplementaryTo(Product p) {
    return complementaryProductIds.contains(p.id);
  }

  // Method to check if the product is trending
  bool get isTrending {
    // Example static threshold for trending products
    const int trendingThreshold = 100; // Define your threshold value
    return purchaseCount >= trendingThreshold;
  }

  int userClicks = 0;

  var categories;

  get selectedVariety => null;

  static Product empty() {
    return Product(
      id: '',
      name: '',
      basePrice: 0.0,
      description: '',
      category: '',
      varieties: [],
      pictureUrl: '',
      purchaseCount: 0,
      recentPurchaseCount: 0,
      reviewCount: 0,
      discountedPrice: 0.0,
      categoryImageUrl: '',
      units: '',
    );
  }

  static fromMap(data) {}
}

// Variety class for handling custom varieties like color, size, etc.
class Variety {
  final String name;
  final String color;
  final String size;
  final String imageUrl;
  final double price;
  final double? discountedPrice; // Nullable field for discounts

  Variety({
    required this.name,
    required this.color,
    required this.size,
    required this.imageUrl,
    required this.price,
    this.discountedPrice, // Initialize the discounted price if applicable
  });

  factory Variety.fromMap(Map<String, dynamic> data) {
    return Variety(
      name: data['name'],
      color: data['color'],
      size: data['size'],
      imageUrl: data['imageUrl'],
      price: data['price'], // Make sure price is parsed
      discountedPrice: data['discountedPrice'] != null
          ? data['discountedPrice'].toDouble()
          : null, // Safe parsing of discounted price
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
      'size': size,
      'imageUrl': imageUrl,
      'price': price,
      'discountedPrice': discountedPrice,
    };
  }
}
