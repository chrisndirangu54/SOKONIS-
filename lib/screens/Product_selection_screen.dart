import 'package:flutter/material.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:provider/provider.dart';

class ProductSelectionScreen extends StatefulWidget {
  final User user;

  const ProductSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  _ProductSelectionScreenState createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  final List<Variety> _selectedVarieties = [];

  void _onVarietySelected(Variety variety, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedVarieties.add(variety);
      } else {
        _selectedVarieties.remove(variety);
      }
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _selectedVarieties);
  }

  void _askForSubscription(Product product, List<Variety> varietiesToSubscribe) {
    final SubscriptionService subscriptionService = SubscriptionService();
    final varieties = List.from(varietiesToSubscribe);

    void showNextVarietyDialog(int index) {
      if (index >= varieties.length) {
        Navigator.pop(context);
        return;
      }

      final Variety variety = varieties[index];
      int selectedFrequency = 7; // Default weekly
      int selectedDay = DateTime.now().weekday; // Default to today
      int quantity = 1; // Default quantity
      final availableFrequencies = [1, 7, 14, 30];
      final weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Subscribe to ${variety.name}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Set subscription details for ${variety.name}:'),
                _buildFrequencyDropdown(selectedFrequency, availableFrequencies, setState),
                _buildDayDropdown(selectedDay, weekDays, setState),
                _buildQuantityControlDialog(quantity, setState),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final nextDelivery = _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                  final subscription = Subscription(
                    product: product,
                    user: widget.user,
                    quantity: quantity,
                    nextDelivery: nextDelivery,
                    frequency: selectedFrequency,
                    price: variety.price,
                    variety: variety,
                  );
                  subscriptionService.addSubscription(subscription, context);
                  Navigator.pop(context);
                  showNextVarietyDialog(index + 1);
                },
                child: const Text('Subscribe'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showNextVarietyDialog(index + 1);
                },
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      );
    }

    if (varieties.isNotEmpty) {
      showNextVarietyDialog(0);
    }
  }

  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime nextDelivery = DateTime.now();
    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }
    return nextDelivery.add(Duration(days: frequency));
  }

  Widget _buildFrequencyDropdown(int selectedFrequency, List<int> availableFrequencies, StateSetter setState) {
    return DropdownButton<int>(
      value: selectedFrequency,
      onChanged: (int? newValue) {
        setState(() {
          selectedFrequency = newValue!;
        });
      },
      items: availableFrequencies.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(value == 1 ? 'Daily' : value == 7 ? 'Weekly' : value == 14 ? 'Bi-weekly' : 'Monthly'),
        );
      }).toList(),
    );
  }

  Widget _buildDayDropdown(int selectedDay, List<String> weekDays, StateSetter setState) {
    return DropdownButton<int>(
      value: selectedDay,
      onChanged: (int? newValue) {
        setState(() {
          selectedDay = newValue!;
        });
      },
      items: List.generate(7, (index) {
        return DropdownMenuItem<int>(
          value: index + 1,
          child: Text(weekDays[index]),
        );
      }),
    );
  }

  Widget _buildQuantityControlDialog(int quantity, StateSetter setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Quantity:'),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (quantity > 1) quantity--;
            });
          },
        ),
        Text(quantity.toString()),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            setState(() {
              quantity++;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Products for Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedVarieties.isNotEmpty ? _confirmSelection : null,
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: productProvider.fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching products'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No products available.'));
          }

          final products = snapshot.data!;

          // Group products by category and subcategory
          Map<String, Map<String, List<Product>>> categorySubcategoryProducts = {};
          for (var product in products) {
            for (var category in product.categories) {
              categorySubcategoryProducts.putIfAbsent(category.name, () => {});
              for (var subcategory in category.subcategories) {
                categorySubcategoryProducts[category.name]!.putIfAbsent(subcategory.name, () => []).add(product);
              }
              if (category.subcategories.isEmpty) {
                categorySubcategoryProducts[category.name]!.putIfAbsent('General', () => []).add(product);
              }
            }
          }

          return ListView(
            children: categorySubcategoryProducts.entries.map((categoryEntry) {
              String categoryName = categoryEntry.key;
              Map<String, List<Product>> subcategoryProducts = categoryEntry.value;

              return ExpansionTile(
                title: Text(categoryName),
                children: subcategoryProducts.entries.map((subcategoryEntry) {
                  String subcategoryName = subcategoryEntry.key;
                  List<Product> productList = subcategoryEntry.value;

                  return ExpansionTile(
                    title: Text(subcategoryName),
                    children: productList.map((product) {
                      return ProductTile(
                        product: product,
                        onSelected: _onVarietySelected,
                        onSubscribe: () {
                          // Filter selected varieties for this product
                          final productVarieties = _selectedVarieties.where((v) => product.varieties.contains(v)).toList();
                          if (productVarieties.isNotEmpty) {
                            _askForSubscription(product, productVarieties);
                          }
                        },
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  final Function(Variety, bool) onSelected;
  final VoidCallback onSubscribe;

  const ProductTile({
    super.key,
    required this.product,
    required this.onSelected,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var variety in product.varieties)
            VarietyTile(
              variety: variety,
              product: product,
              onSelected: (isSelected) => onSelected(variety, isSelected),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.subscriptions),
        onPressed: onSubscribe,
      ),
    );
  }
}

class VarietyTile extends StatefulWidget {
  final Variety variety;
  final Product? product;
  final Function(bool) onSelected;

  const VarietyTile({
    super.key,
    required this.variety,
    this.product,
    required this.onSelected,
  });

  @override
  VarietyTileState createState() => VarietyTileState();
}

class VarietyTileState extends State<VarietyTile> {
  bool _isSelected = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.variety.name),
      subtitle: Text('Color: ${widget.variety.color}, Size: ${widget.variety.size}'),
      trailing: Text(
        '\$${widget.variety.price.toString()}${widget.variety.discountedPrice != null ? " (Discounted: \$${widget.variety.discountedPrice})" : ""}',
      ),
      leading: Image.network(
        widget.variety.imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      ),
      tileColor: _isSelected ? Colors.green[100] : null,
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
        widget.onSelected(_isSelected);
      },
    );
  }
}