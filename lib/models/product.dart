import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/services/groupbuy_service.dart';
import 'package:flutter/material.dart';

class ProductPriceFloating extends StatelessWidget {
  final String userId;
  final String userLocation; // The location passed by the user (city/region)

  const ProductPriceFloating({
    super.key,
    required this.userId,
    required this.userLocation,
  });

  Future<void> cancelGroupBuy(String groupId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('GroupBuy').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      return;
    }

    // Update the user record to remove this group buy
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final activeGroupBuys =
        List<String>.from(userDoc.data()?['activeGroupBuys'] ?? []);
    activeGroupBuys.remove(groupId);
    await userRef.update({'activeGroupBuys': activeGroupBuys});

    // Optionally, delete the group buy from Firestore
    await groupRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('GroupBuy')
              .where('location',
                  isEqualTo: userLocation) // Query based on the user's location
              .where('active',
                  isEqualTo: true) // Check if there's an active group buy
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
              return const SizedBox(); // No active group buy, do not show the widget
            }

            // Get the first group buy document from the query
            final groupBuyDoc = snapshot.data!.docs.first;
            final discountEndTime =
                (groupBuyDoc['endTime'] as Timestamp).toDate();
            final timeLeft = discountEndTime.difference(DateTime.now());

            if (timeLeft.isNegative) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Group Buy Ended',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            final timeLeftFormatted =
                "${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s";

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time Left: $timeLeftFormatted',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: () {
                      cancelGroupBuy(groupBuyDoc.id); // Cancel the group buy
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Cancel Group Buy'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class Product {
  num? rating;
  late final String id;
  final String name;

  final double basePrice;
  final String description;
  late final String category;
  final String units;
  final String categoryImageUrl;
  final List<String> tags;
  final List<String> subcategoryImageUrls;
  final List<Variety> varieties;
  final String pictureUrl;
  final DateTime? lastPurchaseDate;
  final bool isComplementary;
  final List<String> complementaryProductIds;
  final bool isSeasonal;
  final DateTime? seasonStart;
  final DateTime? seasonEnd;
  final Stream<double?>? discountedPriceStream2;
  int purchaseCount;
  int recentPurchaseCount;
  int reviewCount;
  int itemQuantity;
  int views;
  int clicks;
  int favorites;
  int timeSpent;
  List<String>? consumptionTime;
  // New fields
  final bool isFresh;
  final bool isLocallySourced;
  final bool isOrganic;
  final bool hasHealthBenefits;
  final bool hasDiscounts;
  final double discountedPrice;
  final bool isEcoFriendly;
  final bool isSuperfood;

  bool? isGroupActive = false;
  double? groupDiscount = 0.0;
  int? groupSize = 0;
  int? currentGroupMembers = 0;
  double? minPrice = 0.0; // Buying price
  List<Review>? reviews;
  late int userViews;
  late int userTimeSpent;
  List<String>? weather;
  List<Product> genomicAlternatives;
  Product({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.description,
    required this.category,
    required this.categoryImageUrl,
    required this.units,
    this.tags = const [],
    this.subcategoryImageUrls = const [],
    this.varieties = const [],
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
    this.currentGroupMembers,
    this.groupSize,
    this.minPrice,
    this.groupDiscount,
    this.isGroupActive,
    this.discountedPriceStream2,
    this.consumptionTime = const [],
    this.weather = const [],
    this.rating,
    this.reviews,
    this.genomicAlternatives = const [],
  });

// Factory constructor to create a Product instance from Firestore data
  factory Product.fromFirestore({
    DocumentSnapshot<Map<String, dynamic>>? doc,
    GroupBuyService? groupBuyService,
    LatLng? userLocation,
    String? id,
  }) {
    final data = doc?.data() ?? {};

    // Helper function to safely cast and provide defaults
    T safeCast<T>(dynamic value, T defaultValue) {
      if (value is T) return value;
      return defaultValue;
    }

    // Safe casting for various types
    final basePrice = safeCast<double>(data['basePrice'], 0.0);
    final reviewCount = safeCast<int>(data['reviewCount'], 0);
    final purchaseCount = safeCast<int>(data['purchaseCount'], 0);
    final recentPurchaseCount = safeCast<int>(data['recentPurchaseCount'], 0);
    final itemQuantity = safeCast<int>(data['itemQuantity'], 0);
    final views = safeCast<int>(data['views'], 0);
    final clicks = safeCast<int>(data['clicks'], 0);
    final favorites = safeCast<int>(data['favorites'], 0);
    final timeSpent = safeCast<int>(data['timeSpent'], 0);
    final discountedPrice = safeCast<double>(data['discountedPrice'], 0.0);
    final rating = safeCast<double>(
        data['rating'], 0.0); // Assuming 'units' was meant to be 'rating'

    // Handle nullable types
    DateTime? lastPurchaseDate = data['lastPurchaseDate'] != null
        ? (data['lastPurchaseDate'] as Timestamp).toDate()
        : null;
    DateTime? seasonStart = data['seasonStart'] != null
        ? (data['seasonStart'] as Timestamp).toDate()
        : null;
    DateTime? seasonEnd = data['seasonEnd'] != null
        ? (data['seasonEnd'] as Timestamp).toDate()
        : null;

    // Handle lists safely
    List<String> tags = List<String>.from(data['tags'] ?? []);
    List<String> subcategoryImageUrls =
        List<String>.from(data['subcategoryImageUrls'] ?? []);
    List<Variety> varieties = (data['varieties'] as List<Variety>?)
            ?.map((v) => Variety.fromMap(v as Map<String, Variety>))
            .toList() ??
        [];
    List<String> complementaryProductIds =
        List<String>.from(data['complementaryProductIds'] ?? []);
    List<String> consumptionTime =
        List<String>.from(data['consumptionTime'] ?? []);
    List<String> weather = List<String>.from(data['weather'] ?? []);

    return Product(
      id: doc!.id, // Ensure 'doc' is not null here
      name: data['name'] as String? ?? 'Unknown Product',
      basePrice: basePrice,
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      categoryImageUrl: data['categoryImageUrl'] as String? ?? '',
      tags: tags,
      subcategoryImageUrls: subcategoryImageUrls,
      varieties: varieties,
      pictureUrl: data['pictureUrl'] as String? ?? '',
      lastPurchaseDate: lastPurchaseDate,
      complementaryProductIds: complementaryProductIds,
      isSeasonal: data['isSeasonal'] ?? false,
      seasonStart: seasonStart,
      seasonEnd: seasonEnd,
      purchaseCount: purchaseCount,
      recentPurchaseCount: recentPurchaseCount,
      reviewCount: reviewCount,
      itemQuantity: itemQuantity,
      views: views,
      clicks: clicks,
      favorites: favorites,
      timeSpent: timeSpent,
      isFresh: data['isFresh'] ?? false,
      isLocallySourced: data['isLocallySourced'] ?? false,
      isOrganic: data['isOrganic'] ?? false,
      hasHealthBenefits: data['hasHealthBenefits'] ?? false,
      hasDiscounts: data['hasDiscounts'] ?? false,
      isEcoFriendly: data['isEcoFriendly'] ?? false,
      isSuperfood: data['isSuperfood'] ?? false,
      discountedPrice: discountedPrice,
      units: data['units'] as String? ?? '',
      currentGroupMembers: null,
      groupSize: null,
      minPrice: null,
      groupDiscount: null,
      isGroupActive: null,
      discountedPriceStream2: groupBuyService != null && userLocation != null
          ? groupBuyService.getProductDiscountStreamByLocation(userLocation)
          : null,
      consumptionTime: consumptionTime,
      weather: weather,
      rating: rating,
      genomicAlternatives: const [],
    );
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
    const int trendingThreshold = 100;
    return purchaseCount >= trendingThreshold;
  }

  int userClicks = 0;

  User? user;
  Variety? variety;

  get userLocation => user?.pinLocation;

  //get selectedVariety => variety;

  static Product empty() {
    return Product(
      id: '',
      name: '',
      basePrice: 0.0,
      description: '',
      category: '',
      categoryImageUrl: '',
      units: '',
      varieties: [],
      pictureUrl: '',
      purchaseCount: 0,
      recentPurchaseCount: 0,
      reviewCount: 0,
      discountedPrice: 0.0,
      currentGroupMembers: null,
      groupSize: null,
      minPrice: null,
      groupDiscount: null,
      isGroupActive: null,
      discountedPriceStream2: const Stream<double?>.empty(),
    );
  }

  // Add fromMap method to convert a map to a Product instance
  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      basePrice: data['basePrice'] ?? 0.0,
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      categoryImageUrl: data['categoryImageUrl'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      subcategoryImageUrls:
          List<String>.from(data['subcategoryImageUrls'] ?? []),
      varieties: (data['varieties'] as List?)
              ?.map((v) => Variety.fromMap(v))
              .toList() ??
          [],
      pictureUrl: data['pictureUrl'] ?? '',
      lastPurchaseDate: data['lastPurchaseDate'] != null
          ? DateTime.tryParse(data['lastPurchaseDate'])
          : null,
      complementaryProductIds:
          List<String>.from(data['complementaryProductIds'] ?? []),
      isSeasonal: data['isSeasonal'] ?? false,
      seasonStart: data['seasonStart'] != null
          ? DateTime.tryParse(data['seasonStart'])
          : null,
      seasonEnd: data['seasonEnd'] != null
          ? DateTime.tryParse(data['seasonEnd'])
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
      discountedPrice: data['discountedPrice'] ?? 0.0,
      isGroupActive: data['isGroupActive'] ?? false,
      groupDiscount: data['groupDiscount'] ?? 0.0,
      groupSize: data['groupSize'] ?? 0,
      currentGroupMembers: data['currentGroupMembers'] ?? 0,
      minPrice: data['minPrice'] ?? 0.0,
      units: '',
      discountedPriceStream2: data['discountedPriceStream'] ?? 0.0,
      consumptionTime: List<String>.from(data['consumptionTime'] ?? []),
      weather: List<String>.from(data['weather'] ?? []),
      rating: data['rating'] ?? 0,
    );
  }


  // Add toMap method to map Product fields to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'basePrice': basePrice,
      'description': description,
      'category': category,
      'categoryImageUrl': categoryImageUrl,
      'tags': tags,
      'subcategoryImageUrls': subcategoryImageUrls,
      'varieties': varieties.map((v) => v.toMap()).toList(),
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
      'discountedPrice': discountedPrice,
      'isGroupActive': isGroupActive,
      'groupDiscount': groupDiscount,
      'groupSize': groupSize,
      'currentGroupMembers': currentGroupMembers,
      'minPrice': minPrice,
      'discountedPriceStream': discountedPriceStream2,
      'consumptionTime': consumptionTime,
      'weather': weather,
      'rating': rating,
    };
  }

  static Future<List<Product>> fromJson(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      return [];
    }

    List<Product> products = [];
    for (var item in data['products']) {
      products.add(Product.fromJson(item) as Product);
    }

    return products;
  }

  copyWith({required Variety variety, required int quantity}) {}
}

class Variety {
  final String name;
  final String color;
  final String size;
  final String imageUrl;
  final double price;
  final double? discountedPrice;
  final Stream<Map<String, double?>?>? discountedPriceStream;

  Variety({
    required this.name,
    required this.color,
    required this.size,
    required this.imageUrl,
    required this.price,
    this.discountedPrice,
    required this.discountedPriceStream,
  });

  /// Factory method to create a Variety instance from Firestore data
  factory Variety.fromFirestore(
    Map<String, dynamic> data,
    Stream<Map<String, double?>?> discountedPriceStream,
  ) {
    return Variety(
      name: data['name'] as String,
      color: data['color'] as String,
      size: data['size'] as String,
      imageUrl: data['imageUrl'] as String,
      price: (data['price'] as num).toDouble(),
      discountedPrice: (data['discountedPrice'] as num?)?.toDouble(),
      discountedPriceStream: discountedPriceStream,
    );
  }

  /// Convert the Variety instance to a map for Firestore
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

  /// Create a Variety instance from a Map
  factory Variety.fromMap(Map<String, dynamic> map) {
    return Variety(
      name: map['name'] as String,
      color: map['color'] as String,
      size: map['size'] as String,
      imageUrl: map['imageUrl'] as String,
      price: (map['price'] as num).toDouble(),
      discountedPrice: (map['discountedPrice'] as num?)?.toDouble(),
      discountedPriceStream: null, // No stream available in this context
    );
  }

  /// Convert the Variety instance to a map, including stream metadata if needed
  Map<String, dynamic> toMapWithStream() {
    return {
      'name': name,
      'color': color,
      'size': size,
      'imageUrl': imageUrl,
      'price': price,
      'discountedPrice': discountedPrice,
      'discountedPriceStream': discountedPriceStream != null
          ? 'Stream included (not serializable)'
          : null,
    };
  }

  /// Fetch varieties from Firestore
  static Future<List<Variety>> fetchVarieties(
    String groupBuyId,
    LatLng userLocation, {
    double radiusInKm = 1.0,
    required FirebaseFirestore firestore,
  }) async {
    final groupBuySnapshot =
        await firestore.collection('GroupBuy').doc(groupBuyId).get();

    if (!groupBuySnapshot.exists) {
      throw Exception('Group buy not found.');
    }

    final groupBuyData = groupBuySnapshot.data();
    final varietiesData = groupBuyData?['varieties'] as List<dynamic>?;
    if (varietiesData == null) {
      throw Exception('No varieties found.');
    }

    return varietiesData.map((varietyData) {
      final varietyMap = varietyData as Map<String, dynamic>;
      final discountedPriceStream = _getVarietyDiscountStreamByLocation(
        userLocation,
        varietyMap['name'] as String,
        groupBuyId,
        firestore,
        radiusInKm: radiusInKm,
      );

      return Variety.fromFirestore(varietyMap, discountedPriceStream!);
    }).toList();
  }

  /// Get the stream for discounted price of a specific variety
  static Stream<Map<String, double?>?>? _getVarietyDiscountStreamByLocation(
    LatLng userLocation,
    String varietyName,
    String groupBuyId,
    FirebaseFirestore firestore, {
    double radiusInKm = 1.0,
  }) async* {
    yield* firestore
        .collection('GroupBuy')
        .doc(groupBuyId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      final varieties = data['varieties'] as List<dynamic>? ?? [];
      final variety = varieties.firstWhere(
        (v) => v['name'] == varietyName,
        orElse: () => null,
      );

      if (variety == null) return null;

      final basePrice = (variety['price'] ?? data['basePrice']) as double;
      final discountPerMember = data['discountPerMember'] as double? ?? 0.0;
      final currentMembers = (data['members'] as List?)?.length ?? 0;

      final discountedPrice =
          basePrice - (basePrice * discountPerMember * currentMembers);

      return {varietyName: discountedPrice};
    });
  }
}

class Review {
  final String id;
  final String reviewerName;
  final String reviewText;
  final num rating;
  final DateTime reviewDate;

  Review({
    required this.id,
    required this.reviewerName,
    required this.reviewText,
    required this.rating,
    required this.reviewDate,
  });

  // Factory constructor to create Review from Firestore document snapshot
  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Review(
      id: doc.id,
      reviewerName: data['reviewerName'] ?? 'Anonymous',
      reviewText: data['reviewText'] ?? '',
      rating: data['rating'] ?? 0,
      reviewDate: (data['reviewDate'] as Timestamp).toDate(),
    );
  }

// Factory constructor to create Review from a map
  factory Review.fromMap(Map<String, dynamic> map) {
    // Here we assume that the map contains an 'id' field, if not, you might need to handle this case differently
    return Review(
      id: map['id'] ??
          '', // Assuming id is part of the map, otherwise handle this
      reviewerName: map['reviewerName'] ?? 'Anonymous',
      reviewText: map['reviewText'] ?? '',
      rating: map['rating'] ?? 0,
      reviewDate: (map['reviewDate'] as Timestamp).toDate(),
    );
  }
  // Convert Review object to a map for Firestore or other JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'reviewerName': reviewerName,
      'reviewText': reviewText,
      'rating': rating,
      'reviewDate': Timestamp.fromDate(reviewDate),
    };
  }

  // Convert Review to Firestore document
  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  // Create a copy of this review with potentially modified fields
  Review copyWith({
    String? id,
    String? reviewerName,
    String? reviewText,
    int? rating,
    DateTime? reviewDate,
  }) {
    return Review(
      id: id ?? this.id,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewText: reviewText ?? this.reviewText,
      rating: rating ?? this.rating,
      reviewDate: reviewDate ?? this.reviewDate,
    );
  }
}

class Address {
  final String? city;
  final String? town;
  final String? estate;
  final String? buildingName;
  final String? houseNumber;
  final LatLng? pinLocation;

  Address({
    this.city,
    this.town,
    this.estate,
    this.buildingName,
    this.houseNumber,
    this.pinLocation,
  });

  // Factory constructor to create from JSON (if needed for Firestore)
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      city: json['city'] as String?,
      town: json['town'] as String?,
      estate: json['estate'] as String?,
      buildingName: json['buildingName'] as String?,
      houseNumber: json['houseNumber'] as String?,
      pinLocation: json['pinLocation'] != null
          ? LatLng(
              json['pinLocation']['latitude'] as double,
              json['pinLocation']['longitude'] as double,
            )
          : null,
    );
  }

  // Method to convert to JSON (if needed for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'town': town,
      'estate': estate,
      'buildingName': buildingName,
      'houseNumber': houseNumber,
      'pinLocation': pinLocation != null
          ? {
              'latitude': pinLocation!.latitude,
              'longitude': pinLocation!.longitude,
            }
          : null,
    };
  }

  // Create a copy with updated values
  Address copyWith({
    String? city,
    String? town,
    String? estate,
    String? buildingName,
    String? houseNumber,
    LatLng? pinLocation,
  }) {
    return Address(
      city: city ?? this.city,
      town: town ?? this.town,
      estate: estate ?? this.estate,
      buildingName: buildingName ?? this.buildingName,
      houseNumber: houseNumber ?? this.houseNumber,
      pinLocation: pinLocation ?? this.pinLocation,
    );
  }
}
