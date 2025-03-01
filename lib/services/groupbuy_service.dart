import 'dart:async';
import 'dart:math';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:grocerry/models/group_buy_model.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';

class GroupBuyService {
  final FirebaseFirestore _firestore;
  final Product? _product;

  // BehaviorSubject to keep the last value for new subscribers
  final BehaviorSubject<double?> _discountedPriceSubject = BehaviorSubject<double?>();
  Stream<double?> get discountedPriceStream => _discountedPriceSubject.stream;

  GroupBuyService(this._firestore, this._product) {
    // Initialize the stream with null
    _discountedPriceSubject.add(null);
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadiusKm = 6371.0;

    double lat1 = a.latitude * pi / 180;
    double lon1 = a.longitude * pi / 180;
    double lat2 = b.latitude * pi / 180;
    double lon2 = b.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double haversine = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(haversine), sqrt(1 - haversine));

    return earthRadiusKm * c;
  }

  Stream<double?> getProductDiscountStreamByLocation(
    LatLng userLocation, {
    double radiusInKm = 1.0,
  }) async* {
    await for (var snapshot in _firestore
        .collection('GroupBuy')
        .where('active', isEqualTo: true)
        .snapshots()) {
      try {
        final nearbyGroupBuys = snapshot.docs.where((doc) {
          final groupBuyLocation = LatLng(
            (doc['location'] as Map<String, dynamic>)['latitude'] as double,
            (doc['location'] as Map<String, dynamic>)['longitude'] as double,
          );
          return _calculateDistance(userLocation, groupBuyLocation) <= radiusInKm;
        }).toList();

        if (nearbyGroupBuys.isEmpty) {
          yield null;
        } else {
          double? discountedPrice = _getDiscountedPrice(nearbyGroupBuys.first.data());
          yield discountedPrice;
        }
      } catch (e) {
        print('Error in group buy snapshot subscription: $e');
        yield null;
      }
    }
  }

  double? _getDiscountedPrice(Map<String, dynamic> groupBuyData) {
    final basePrice = groupBuyData['basePrice'] as double? ?? 0.0;
    final discountPerMember = groupBuyData['discountPerMember'] as double? ?? 0.0;
    final currentMembers = (groupBuyData['members'] as List<dynamic>?)?.length ?? 0;

    double? discountedPrice = basePrice - (basePrice * discountPerMember * currentMembers);
    return discountedPrice.clamp(_product?.minPrice ?? 0, basePrice);
  }

  Stream<Map<String, double?>> getVarietiesDiscountStreamByLocation(
    LatLng userLocation, {
    double radiusInKm = 1.0,
  }) async* {
    await for (var snapshot in _firestore
        .collection('GroupBuy')
        .where('active', isEqualTo: true)
        .snapshots()) {
      try {
        final nearbyGroupBuys = snapshot.docs.where((doc) {
          final groupBuyLocation = LatLng(
            (doc['location'] as Map<String, dynamic>)['latitude'] as double,
            (doc['location'] as Map<String, dynamic>)['longitude'] as double,
          );
          return _calculateDistance(userLocation, groupBuyLocation) <= radiusInKm;
        }).toList();

        if (nearbyGroupBuys.isEmpty) {
          yield {};
        } else {
          Map<String, double?> discounts = {};
          for (var doc in nearbyGroupBuys) {
            discounts.addAll(_getVarietyDiscounts(doc.data()));
          }
          yield discounts;
        }
      } catch (e) {
        print('Error in group buy snapshot subscription: $e');
        yield {};
      }
    }
  }

  Map<String, double?> _getVarietyDiscounts(Map<String, dynamic> groupBuyData) {
    final basePrice = groupBuyData['basePrice'] as double? ?? 0.0;
    final discountPerMember = groupBuyData['discountPerMember'] as double? ?? 0.0;
    final currentMembers = (groupBuyData['members'] as List<dynamic>?)?.length ?? 0;

    Map<String, double?> discounts = {};
    List<dynamic>? varietiesData = groupBuyData['varieties'];
    if (varietiesData != null) {
      for (var variety in varietiesData) {
        String varietyName = variety['name'];
        double varietyBasePrice = variety['price'] ?? basePrice;
        double discountedPrice = varietyBasePrice - (varietyBasePrice * discountPerMember * currentMembers);
        discounts[varietyName] = discountedPrice.clamp(_product?.minPrice ?? 0, varietyBasePrice);
      }
    }
    return discounts;
  }

  Future<void> joinGroupBuy(String groupId, User user) async {
    final groupRef = _firestore.collection('GroupBuy').doc(groupId);

    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) return;

      List<String> members = List<String>.from(groupSnapshot.data()?['members'] ?? []);
      if (!members.contains(user.id)) {
        members.add(user.id);
        transaction.update(groupRef, {'members': members});

        final userRef = _firestore.collection('users').doc(user.id);
        final userSnapshot = await transaction.get(userRef);
        List<String> activeGroupBuys = List<String>.from(userSnapshot.data()?['activeGroupBuys'] ?? []);
        activeGroupBuys.add(groupId);
        transaction.update(userRef, {'activeGroupBuys': activeGroupBuys});
      }
    });
  }

  Future<void> resetGroupBuy(String groupId) async {
    final groupRef = _firestore.collection('GroupBuy').doc(groupId);
    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) return;

    List<String> members = List<String>.from(groupSnapshot.data()?['members'] ?? []);

    for (var userId in members) {
      final userRef = _firestore.collection('users').doc(userId);
      final userSnapshot = await userRef.get();
      List<String> activeGroupBuys = List<String>.from(userSnapshot.data()?['activeGroupBuys'] ?? []);
      activeGroupBuys.remove(groupId);
      await userRef.update({'activeGroupBuys': activeGroupBuys});
    }

    await groupRef.delete();
  }

  Future<String> createGroupBuy(User hostId, LatLng userLocation) async {
    final groupId = _firestore.collection('GroupBuy').doc().id;
    final now = DateTime.now();
    final groupBuy = GroupBuy(
      id: groupId,
      userLocation: userLocation,
      hostId: hostId,
      currentPrice: _product?.basePrice ?? 0.0,
      minPrice: _product?.minPrice ?? 0.0,
      startTime: now,
      endTime: now.add(const Duration(minutes: 5)),
    );

    await _firestore.collection('GroupBuy').doc(groupId).set(groupBuy.toMap());
    return groupId;
  }

  Stream<List<GroupBuy>> fetchActiveGroupBuys() {
    return _firestore
        .collection('GroupBuy')
        .where('endTime', isGreaterThan: Timestamp.now())
        .snapshots()
        .asyncMap((snapshot) async {
          final groupBuyFutures = snapshot.docs.map((doc) => GroupBuy.fromSnapshot(doc)).toList();
          final groupBuys = await Future.wait(groupBuyFutures);
          return groupBuys.where((groupBuy) => groupBuy.isActive).toList();
        });
  }

  // Update the discounted price in the stream
  void updateDiscountedPrice(double? newDiscountedPrice) {
    _discountedPriceSubject.add(newDiscountedPrice);
  }

  // Method to update Firestore and the stream
  Future<void> _updateProductDiscount(String productId, double? newDiscountedPrice) async {
    try {
      final productDoc = await _firestore.collection('products').doc(productId).get();

      if (productDoc.exists) {
        await _firestore.collection('products').doc(productId).update({'discountedPrice': newDiscountedPrice});

        // Update the discounted price in the service's stream
        updateDiscountedPrice(newDiscountedPrice);
      } else {
        print('Product with ID $productId does not exist.');
      }
    } catch (e) {
      print('Error updating product discount: $e');
    }
  }

  // Clean up resources
  void dispose() {
    _discountedPriceSubject.close();
  }
}