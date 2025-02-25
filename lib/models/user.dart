import 'package:flutter/material.dart'; // Required for ChangeNotifier
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class User with ChangeNotifier {
  final String id; // Firebase Auth uid
  final String uid;
  final String email;
  final String? token;
  final String name;
  final Address? address;
  LatLng? pinLocation; // Public field
  final String profilePictureUrl;
  final List<String> favoriteProductIds;
  final List<String> recentlyBoughtProductIds;
  final DateTime? lastLoginDate;
  final String contact;
  final String? referralCode;
  final String? referredBy;
  final bool isBlacklisted;

  // Admin-specific fields
  final bool isAdmin;
  final bool canManageUsers;
  final bool canManageProducts;
  final bool canViewReports;
  final bool canEditSettings;

  // Rider-specific fields
  bool isRider; // Public field
  final bool isAvailableForDelivery;
  LatLng? liveLocation;

  // Attendant-specific fields
  final bool isAttendant;
  final bool canConfirmPreparing;
  final bool canConfirmReadyForDelivery;

  User({
    required this.id,
    required this.uid,
    required this.email,
    this.token,
    this.isBlacklisted = false,
    required this.name,
    this.address,
    this.pinLocation,
    required this.profilePictureUrl,
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
  }) {
    updateRiderLocation(); // Initial update
  }

  // Method to update riderLocation and notify listeners
  void updateRiderLocation({LatLng? newPinLocation, bool? newIsRider}) {
    if (newPinLocation != null) pinLocation = newPinLocation;
    if (newIsRider != null) isRider = newIsRider;
    if (isRider && pinLocation != null) {
      liveLocation = pinLocation;
    } else {
      liveLocation = null; // or some default value
    }
    notifyListeners();
  }

  // Factory constructor to create a User instance from JSON data
  factory User.fromJson(Map<String, dynamic> json) {
    final user = User(
      id: json['id'] ?? '',
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      token: json['token'],
      name: json['name'] ?? '',
      address: json['address'],
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
      referralCode: json['referralCode'],
      referredBy: json['referredBy'],
    );
    return user;
  }

  // Static method to create a guest user with a persistent ID
  static Future<User> guest() async {
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString('guestId');

    if (guestId == null) {
      guestId = const Uuid().v4();
      await prefs.setString('guestId', guestId);
    }

    return User(
      id: guestId,
      uid: guestId,
      email: 'guest@example.com',
      name: 'Guest',
      address: null,
      profilePictureUrl: '',
      contact: 'N/A',
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
      'referralCode': referralCode,
      'referredBy': referredBy,
    };
  }

  // CopyWith method
  User copyWith({
    String? id,
    String? email,
    String? token,
    String? name,
    Address? address,
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
    final newUser = User(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      token: token ?? this.token,
      name: name ?? this.name,
      address: address ?? this.address,
      pinLocation: pinLocation ?? this.pinLocation,
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
      contact: contact ?? this.contact,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
    );
    return newUser;
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
      'referralCode': referralCode,
      'referredBy': referredBy,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isBlacklisted': isBlacklisted,
    };
  }
}
