import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add ingredients to the user's grocery list in Firestore
  Future<void> addIngredientsToList(List<String> ingredients, String userId) async {
    try {
      await _firestore.collection('users')
        .doc(userId)
        .collection('groceryLists')
        .add({
          'ingredients': ingredients,
          'createdAt': DateTime.now(),
        });
    } catch (e) {
      throw Exception('Error adding ingredients to grocery list: $e');
    }
  }

  // Retrieve grocery lists for the user
  Future<List<GroceryList>> getGroceryLists(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceryLists')
          .get();

      return snapshot.docs
          .map((doc) => GroceryList.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching grocery lists: $e');
    }
  }
}

// Grocery List Model
class GroceryList {
  final String id;
  final List<String> ingredients;
  final DateTime createdAt;

  GroceryList({required this.id, required this.ingredients, required this.createdAt});

  factory GroceryList.fromFirestore(DocumentSnapshot doc) {
    return GroceryList(
      id: doc.id,
      ingredients: List<String>.from(doc['ingredients']),
      createdAt: (doc['createdAt'] as Timestamp).toDate(),
    );
  }
}
