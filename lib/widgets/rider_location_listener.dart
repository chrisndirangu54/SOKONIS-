import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderLocationListener extends StatelessWidget {
  final String riderId;

  const RiderLocationListener({super.key, required this.riderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          LatLng riderLocation =
              LatLng(data['liveLocation']['lat'], data['liveLocation']['lng']);

          // You can now use riderLocation in your map to show their position
          return Text(
              'Rider Location: ${riderLocation.latitude}, ${riderLocation.longitude}');
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
