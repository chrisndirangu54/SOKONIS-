import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'status': status,
    });
  }

  Stream<DocumentSnapshot> getDeliveryStatusStream(String deliveryId) {
    return _firestore.collection('deliveries').doc(deliveryId).snapshots();
  }
}
