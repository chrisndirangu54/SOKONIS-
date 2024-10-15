import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderLocationService {
  // Stream to continuously track rider location
  Stream<Position> getRiderLocationStream(LocationAccuracy locationAccuracy) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: locationAccuracy,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  // Method to update rider's live location in the backend
  Future<void> updateRiderLocationInBackend(
      LatLng newLocation, String userId) async {
    // Example of updating in Firebase
    await FirebaseFirestore.instance.collection('riders').doc(userId).update({
      'liveLocation': {
        'lat': newLocation.latitude,
        'lng': newLocation.longitude
      },
    });
  }
}
