import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/offer.dart';

class OfferProvider with ChangeNotifier {
  List<Offer> _offers = [];
  Stream<List<Offer>> get offerStream => _offerStreamController.stream;

  final StreamController<List<Offer>> _offerStreamController =
      StreamController<List<Offer>>.broadcast();

  OfferProvider() {
    _listenToOffers();
  }

  List<Offer> get offers => [..._offers];

  Future<List<Offer>> fetchOffers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('offers').get();
      _offers = snapshot.docs
          .map((doc) =>
              Offer.fromFirestore(doc.data(), doc.id))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching offers: $e');
      return _offers;
    }
    return _offers;
  }

  void _listenToOffers() {
    FirebaseFirestore.instance.collection('offers').snapshots().listen(
        (snapshot) {
      _offers = snapshot.docs
          .map((doc) =>
              Offer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      _offerStreamController.add(_offers);
      notifyListeners();
    }, onError: (e) {
      print('Error listening to offers: $e');
    });
  }

  Future<void> addOffer(Offer offer) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('offers')
          .add(offer.toMap());
      final newOffer = offer.copyWith(id: docRef.id);
      _offers.add(newOffer);
      await _updateProductDiscount(newOffer.productId,
          newOffer.discountedPrice); // Apply discount immediately
      notifyListeners();
    } catch (e) {
      print('Error adding offer: $e');
    }
  }

  Future<void> deleteOffer(String id) async {
    try {
      // Fetch the offer to delete
      final offerToDelete = _offers.firstWhere((offer) => offer.id == id,
          orElse: () => Offer(
              id: id,
              title: '',
              description: '',
              price: 0,
              discountedPrice: 0,
              productId: '',
              imageUrl: '',
              startDate: null,
              endDate: null)); // Provide a default Offer

      if (offerToDelete.id.isNotEmpty) {
        // Check if offerToDelete is valid
        await FirebaseFirestore.instance.collection('offers').doc(id).delete();
        _offers.remove(offerToDelete);
        await _updateProductDiscount(
            offerToDelete.productId, null); // Reset discount
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting offer: $e');
    }
  }

  Future<void> updateOffer(Offer offer) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offer.id)
          .update(offer.toMap());
      final offerIndex =
          _offers.indexWhere((element) => element.id == offer.id);
      if (offerIndex >= 0) {
        _offers[offerIndex] = offer;
        await _updateProductDiscount(
            offer.productId, offer.discountedPrice); // Update product discount
        notifyListeners();
      }
    } catch (e) {
      print('Error updating offer: $e');
    }
  }

  Future<void> _updateProductDiscount(
      String productId, double? discountedPrice) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({'discountedPrice': discountedPrice});
      } else {
        print('Product with ID $productId does not exist.');
      }
    } catch (e) {
      print('Error updating product discount: $e');
    }
  }

  @override
  void dispose() {
    _offerStreamController.close();
    super.dispose();
  }
}
