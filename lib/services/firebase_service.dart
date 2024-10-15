import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateLocationInFirestore(
      LatLng location, String deliveryId) async {
    await _firestore.collection('deliveries').doc(deliveryId).set({
      'lat': location.latitude,
      'lng': location.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> getLocationStream(String deliveryId) {
    return _firestore.collection('deliveries').doc(deliveryId).snapshots();
  }
}
