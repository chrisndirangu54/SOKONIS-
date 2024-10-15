import 'package:google_maps_flutter/google_maps_flutter.dart';

class User {
  final String id; // Firebase Auth uid
  final String uid;
  final String email;
  final String? token;
  final String name;
  final String address;
  final LatLng? pinLocation;
  final String profilePictureUrl;
  final List<String> favoriteProductIds;
  final List<String> recentlyBoughtProductIds;
  final DateTime? lastLoginDate;
  final String contact;
  final String? referralCode;
  final String? referredBy;

  // Admin-specific fields
  final bool isAdmin;
  final bool canManageUsers;
  final bool canManageProducts;
  final bool canViewReports;
  final bool canEditSettings;

  // Rider-specific fields
  final bool isRider;
  final bool isAvailableForDelivery;
  final LatLng? liveLocation;

  // Attendant-specific fields
  final bool isAttendant;
  final bool canConfirmPreparing;
  final bool canConfirmReadyForDelivery;

  User({
    required this.id,
    required this.uid,
    required this.email,
    required this.token,
    required this.name,
    required this.address,
    required this.profilePictureUrl,
    required this.pinLocation,
    this.favoriteProductIds = const [],
    this.recentlyBoughtProductIds = const [],
    this.lastLoginDate,
    this.isAdmin = false,
    this.canManageUsers = false,
    this.canManageProducts = false,
    this.canViewReports = false,
    this.canEditSettings = false,
    this.isRider = false,
    this.isAvailableForDelivery = false,
    this.liveLocation,
    this.isAttendant = false,
    this.canConfirmPreparing = false,
    this.canConfirmReadyForDelivery = false,
    required this.contact,
    this.referralCode,
    this.referredBy,
  });

  // Factory constructor to create a User instance from JSON data
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      profilePictureUrl: json['profilePictureUrl'] ?? '',
      favoriteProductIds: List<String>.from(json['favoriteProductIds'] ?? []),
      recentlyBoughtProductIds:
          List<String>.from(json['recentlyBoughtProductIds'] ?? []),
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'])
          : null,
      isAdmin: json['isAdmin'] ?? false,
      canManageUsers: json['canManageUsers'] ?? false,
      canManageProducts: json['canManageProducts'] ?? false,
      canViewReports: json['canViewReports'] ?? false,
      canEditSettings: json['canEditSettings'] ?? false,
      isRider: json['isRider'] ?? false,
      isAvailableForDelivery: json['isAvailableForDelivery'] ?? false,
      liveLocation: json['liveLocation'] != null
          ? LatLng(json['liveLocation']['lat'], json['liveLocation']['lng'])
          : null,
      isAttendant: json['isAttendant'] ?? false,
      canConfirmPreparing: json['canConfirmPreparing'] ?? false,
      canConfirmReadyForDelivery: json['canConfirmReadyForDelivery'] ?? false,
      contact: json['contact'] ?? '',
      pinLocation: json['pinLocation'] != null
          ? LatLng(json['pinLocation']['lat'], json['pinLocation']['lng'])
          : null,
    );
  }

  // Method to convert User instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'email': email,
      'token': token,
      'name': name,
      'address': address,
      'pinLocation': pinLocation != null
          ? {'lat': pinLocation!.latitude, 'lng': pinLocation!.longitude}
          : null,
      'profilePictureUrl': profilePictureUrl,
      'favoriteProductIds': favoriteProductIds,
      'recentlyBoughtProductIds': recentlyBoughtProductIds,
      'lastLoginDate': lastLoginDate?.toIso8601String(),
      'isAdmin': isAdmin,
      'canManageUsers': canManageUsers,
      'canManageProducts': canManageProducts,
      'canViewReports': canViewReports,
      'canEditSettings': canEditSettings,
      'isRider': isRider,
      'isAvailableForDelivery': isAvailableForDelivery,
      'liveLocation': liveLocation != null
          ? {'lat': liveLocation!.latitude, 'lng': liveLocation!.longitude}
          : null,
      'isAttendant': isAttendant,
      'canConfirmPreparing': canConfirmPreparing,
      'canConfirmReadyForDelivery': canConfirmReadyForDelivery,
      'contact': contact,
    };
  }

  // CopyWith method
  User copyWith({
    String? id,
    String? email,
    String? token,
    String? name,
    String? address,
    LatLng? pinLocation,
    String? profilePictureUrl,
    List<String>? favoriteProductIds,
    List<String>? recentlyBoughtProductIds,
    DateTime? lastLoginDate,
    bool? isAdmin,
    bool? canManageUsers,
    bool? canManageProducts,
    bool? canViewReports,
    bool? canEditSettings,
    bool? isRider,
    bool? isAvailableForDelivery,
    LatLng? liveLocation,
    bool? isAttendant,
    bool? canConfirmPreparing,
    bool? canConfirmReadyForDelivery,
    String? uid,
    String? contact,
    String? referralCode,
    String? referredBy,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      token: token ?? this.token,
      name: name ?? this.name,
      address: address ?? this.address,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      recentlyBoughtProductIds:
          recentlyBoughtProductIds ?? this.recentlyBoughtProductIds,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      isAdmin: isAdmin ?? this.isAdmin,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canManageProducts: canManageProducts ?? this.canManageProducts,
      canViewReports: canViewReports ?? this.canViewReports,
      canEditSettings: canEditSettings ?? this.canEditSettings,
      isRider: isRider ?? this.isRider,
      isAvailableForDelivery:
          isAvailableForDelivery ?? this.isAvailableForDelivery,
      liveLocation: liveLocation ?? this.liveLocation,
      isAttendant: isAttendant ?? this.isAttendant,
      canConfirmPreparing: canConfirmPreparing ?? this.canConfirmPreparing,
      canConfirmReadyForDelivery:
          canConfirmReadyForDelivery ?? this.canConfirmReadyForDelivery,
      uid: uid ?? this.uid,
      contact: contact ?? this.contact,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      pinLocation: pinLocation ?? this.pinLocation,
    );
  }

  factory User.guest() {
    return User(
      id: 'Guest',
      email: 'Guest',
      token: 'Guest',
      name: 'Guest',
      address: 'Guest',
      profilePictureUrl: 'Guest',
      uid: 'Guest',
      contact: 'Guest',
      pinLocation: null, // Pin location can be null for Guest
    );
  }

  // Method to convert User instance to a Map (for Firestore or other map-based storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'email': email,
      'token': token,
      'name': name,
      'address': address,
      'profilePictureUrl': profilePictureUrl,
      'favoriteProductIds': favoriteProductIds,
      'recentlyBoughtProductIds': recentlyBoughtProductIds,
      'lastLoginDate':
          lastLoginDate?.toIso8601String(), // Converts DateTime to a String
      'isAdmin': isAdmin,
      'canManageUsers': canManageUsers,
      'canManageProducts': canManageProducts,
      'canViewReports': canViewReports,
      'canEditSettings': canEditSettings,
      'isRider': isRider,
      'isAvailableForDelivery': isAvailableForDelivery,
      'liveLocation': liveLocation != null
          ? {'lat': liveLocation!.latitude, 'lng': liveLocation!.longitude}
          : null, // Handles the nested liveLocation field
      'isAttendant': isAttendant,
      'canConfirmPreparing': canConfirmPreparing,
      'canConfirmReadyForDelivery': canConfirmReadyForDelivery,
      'contact': contact,
      'pinLocation': pinLocation != null
          ? {'lat': pinLocation!.latitude, 'lng': liveLocation!.longitude}
          : null, // Handles the nested liveLocation field
    };
  }
}
