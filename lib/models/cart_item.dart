import 'package:grocerry/models/user.dart';

import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  String? selectedVariety;
  double price;
  String? notes;

  User? user; // New field for notes

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedVariety,
    required this.price,
    this.notes,
    this.user, // Initialize user field
  });
}
