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

  void _askForSubscription(Product product) {
    final SubscriptionService subscriptionService = SubscriptionService();
    final varietiesToSubscribe = List.from(_selectedVarieties); // Copy to iterate

    // Function to show dialog for the next variety
    void showNextVarietyDialog(int index) {
      if (index >= varietiesToSubscribe.length) {
        // All varieties processed, close the dialog sequence
        Navigator.pop(context);
        return;
      }

      final Variety variety = varietiesToSubscribe[index];
      int selectedFrequency = 7; // Default weekly frequency
      int selectedDay = DateTime.now().weekday; // Default to today’s weekday
      int quantity = 1; // Default quantity
      final availableFrequencies = [1, 7, 14, 30]; // Daily, weekly, bi-weekly, monthly
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
        barrierDismissible: false, // Prevent closing until all are processed
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Subscribe to ${variety.name}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Set subscription details for ${variety.name}:'),
                _buildFrequencyDropdown(
                    selectedFrequency, availableFrequencies, setState),
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
                    price: variety.price, // Use variety-specific price
                    variety: variety,
                  );
                  subscriptionService.addSubscription(subscription, context);
                  Navigator.pop(context); // Close current dialog
                  showNextVarietyDialog(index + 1); // Show next variety
                },
                child: const Text('Subscribe'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Skip this variety
                  showNextVarietyDialog(index + 1); // Move to next
                },
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      );
    }

    // Start with the first variety
    if (varietiesToSubscribe.isNotEmpty) {
      showNextVarietyDialog(0);
    }
  }

  // Helper methods remain unchanged
  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime nextDelivery = DateTime.now();
    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }
    return nextDelivery.add(Duration(days: frequency)); // Add frequency for first delivery
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
            onPressed: _confirmSelection,
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
                    onSelected: _onVarietySelected,
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

// ProductTile and VarietyTile remain unchanged
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
              onSelected: (isSelected) => onSelected(variety, isSelected),
            ),
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
      subtitle: Text('Color: ${widget.variety.color}, Size: ${widget.variety.size}'),
      trailing: Text(
        '\$${widget.variety.price.toString()}${widget.variety.discountedPrice != null ? " (Discounted: \$${widget.variety.discountedPrice})" : ""}',
      ),
      leading: Image.network(
        widget.variety.imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
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