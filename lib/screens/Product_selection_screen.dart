import 'package:flutter/material.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/services/subscription_service.dart'; // Import SubscriptionService
import 'package:provider/provider.dart';

class ProductSelectionScreen extends StatefulWidget {
  final User user; // Change the type from String to User

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

  // Ask for subscription dialog
  void _askForSubscription(Product product) {
    int selectedFrequency = 7; // Default weekly frequency
    int selectedDay = DateTime.now().weekday; // Default to today’s weekday
    int quantity = 1; // Default quantity
    final SubscriptionService subscriptionService = SubscriptionService();

    final availableFrequencies = [
      1,
      7,
      14,
      30
    ]; // Daily, weekly, bi-weekly, monthly
    final weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Subscribe for Auto-Replenishment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Would you like to subscribe to auto-replenish this product?'),
              _buildFrequencyDropdown(
                  selectedFrequency, availableFrequencies, setState),
              _buildDayDropdown(selectedDay, weekDays, setState),
              _buildQuantityControlDialog(quantity, setState),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nextDelivery =
                    _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                final subscription = Subscription(
                  product: product, // Assuming product has an id field
                  user: widget.user, // Assuming user has an id field
                  quantity: quantity,
                  nextDelivery: nextDelivery,
                  frequency: selectedFrequency,
                  price: product.basePrice, variety: product.selectedVariety,
                );
                subscriptionService.addSubscription(subscription, context);
                Navigator.pop(context);
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to calculate the next delivery date
  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime nextDelivery = DateTime.now();
    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }
    return nextDelivery;
  }

  // Helper widget for frequency dropdown
  Widget _buildFrequencyDropdown(int selectedFrequency,
      List<int> availableFrequencies, StateSetter setState) {
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
          child: Text(value == 1
              ? 'Daily'
              : value == 7
                  ? 'Weekly'
                  : value == 14
                      ? 'Bi-weekly'
                      : 'Monthly'),
        );
      }).toList(),
    );
  }

  // Helper widget for day dropdown
  Widget _buildDayDropdown(
      int selectedDay, List<String> weekDays, StateSetter setState) {
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

  // Helper widget for quantity control
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
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Products for Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmSelection,
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: productProvider.fetchProducts(), // Fetch all available products
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

          // Group products by category
          Map<String, List<Product>> categoryProducts = {};
          for (var product in products) {
            if (!categoryProducts.containsKey(product.category)) {
              categoryProducts[product.category] = [];
            }
            categoryProducts[product.category]!.add(product);
          }

          return ListView(
            children: categoryProducts.entries.map((entry) {
              String category = entry.key;
              List<Product> categoryList = entry.value;

              return ExpansionTile(
                title: Text(category),
                children: categoryList.map((product) {
                  return ProductTile(
                    product: product,
                    onSelected: (variety, isSelected) {
                      _onVarietySelected(variety, isSelected);
                      if (isSelected) {
                        // When a product is selected, ask for subscription
                        _askForSubscription(product);
                      }
                    },
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

  const ProductTile({
    super.key,
    required this.product,
    required this.onSelected,
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
                onSelected: (isSelected) {
                  onSelected(
                      variety, isSelected); // Pass variety and selection state
                }),
        ],
      ),
    );
  }
}

class VarietyTile extends StatefulWidget {
  final Variety variety;
  final Function(bool) onSelected;

  const VarietyTile({
    super.key,
    required this.variety,
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
      subtitle:
          Text('Color: ${widget.variety.color}, Size: ${widget.variety.size}'),
      trailing: Text(
        '\$${widget.variety.price.toString()}${widget.variety.discountedPrice != null ? " (Discounted: \$${widget.variety.discountedPrice})" : ""}',
      ),
      leading: Image.network(
        widget.variety.imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      ),
      tileColor:
          _isSelected ? Colors.green[100] : null, // Change color if selected
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
        widget.onSelected(_isSelected);
      },
    );
  }
}
