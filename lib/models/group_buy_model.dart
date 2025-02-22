import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:grocerry/models/user.dart';

class GroupBuy {
  late String id;
  late LatLng userLocation;
  late User hostId;
  late double currentPrice;
  late double minPrice;
  late DateTime startTime;
  late DateTime endTime;
  bool _isActive = true;
  List<String> members = [];
  double basePrice = 0.0;
  double discountPerMember = 0.0;
  List<Map<String, dynamic>>? varieties;

  GroupBuy({
    required this.id,
    required this.userLocation,
    required this.hostId,
    required this.currentPrice,
    required this.minPrice,
    required this.startTime,
    required this.endTime,
  });

  // Constructor to create from Firestore document
  GroupBuy.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic>? data = doc.data();
    if (data != null) {
      id = doc.id;
      userLocation = LatLng(
        (data['location'] as Map<String, dynamic>)['latitude'],
        (data['location'] as Map<String, dynamic>)['longitude'],
      );
      hostId = data['hostId'];
      currentPrice = data['currentPrice']?.toDouble() ?? 0.0;
      minPrice = data['minPrice']?.toDouble() ?? 0.0;
      startTime = (data['startTime'] as Timestamp).toDate();
      endTime = (data['endTime'] as Timestamp).toDate();
      _isActive = data['isActive'] ?? true;
      members = List<String>.from(data['members'] ?? []);
      basePrice = data['basePrice']?.toDouble() ?? 0.0;
      discountPerMember = data['discountPerMember']?.toDouble() ?? 0.0;
      varieties = data['varieties']?.cast<Map<String, dynamic>>();
    }
  }

  // Convert GroupBuy object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'location': {'latitude': userLocation.latitude, 'longitude': userLocation.longitude},
      'hostId': hostId,
      'currentPrice': currentPrice,
      'minPrice': minPrice,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': isActive,
      'members': members,
      'basePrice': basePrice,
      'discountPerMember': discountPerMember,
      'varieties': varieties,
    };
  }

  // Check if the group buy is still active
  bool get isActive => DateTime.now().isBefore(endTime) && _isActive;

  // Optional method to update the group buy's status
  void updateStatus() {
    _isActive = DateTime.now().isBefore(endTime);
  }
}