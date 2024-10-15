import 'package:grocerry/models/user.dart';

import 'product.dart';

class CartItem {
  final User user;
  final Product product;
  final int quantity;
  final double price;

  CartItem({
    required this.user,
    required this.product,
    required this.quantity,
    required this.price, // Include price in the constructor
  });
}
