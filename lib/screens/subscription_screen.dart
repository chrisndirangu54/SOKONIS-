import 'package:flutter/material.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/Product_selection_screen.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final String user; // The logged-in user's details are passed here

  SubscriptionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
      ),
      body: Column(
        children: [
          // Benefits section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benefits of Auto-Replenishment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '- Enjoy free delivery with an active subscription.\n'
                      '- Never run out of your favorite items with scheduled deliveries.\n'
                      '- Get exclusive discounts on your auto-replenished orders.\n'
                      '- Modify or cancel your subscription anytime.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Subscription list section
          Expanded(
            child: StreamBuilder<List<Subscription>>(
              stream: _subscriptionService.getUserSubscriptions(user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error fetching subscriptions'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No active subscriptions found.'));
                }

                final subscriptions = snapshot.data!;
                return ListView.builder(
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = subscriptions[index];
                    return SubscriptionTile(
                      subscription: subscription,
                      user: user,
                      onScheduleChange: (updatedSubscription) {
                        _subscriptionService
                            .updateSubscription(updatedSubscription);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionTile extends StatefulWidget {
  final Subscription subscription;
  final String user;

  final Function(Subscription) onScheduleChange;

  const SubscriptionTile({
    super.key,
    required this.subscription,
    required this.user,
    required this.onScheduleChange,
  });

  @override
  SubscriptionTileState createState() => SubscriptionTileState();
}

class SubscriptionTileState extends State<SubscriptionTile> {
  late int quantity;

  @override
  void initState() {
    super.initState();
    quantity =
        widget.subscription.quantity; // Initialize quantity from subscription
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Product: ${widget.subscription.product}'),
      subtitle: Text('Next Delivery: ${widget.subscription.nextDelivery}'),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuantityControl(),
          _buildSwitch(),
          _buildCartButton(),
          _buildAddProductButton(),
        ],
      ),
      onTap: () => _showSubscriptionOptions(context),
    );
  }

  // Quantity control widget
  Widget _buildQuantityControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.white),
          onPressed: () {
            if (quantity > 1) {
              setState(() {
                quantity--; // Decrease quantity
              });
            }
          },
        ),
        Text('$quantity',
            style: const TextStyle(color: Colors.white, fontSize: 20)),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            setState(() {
              quantity++; // Increase quantity
            });
          },
        ),
      ],
    );
  }

// Subscription toggle switch
  Widget _buildSwitch() {
    return Switch(
      value: widget.subscription.isActive,
      onChanged: (val) {
        widget.onScheduleChange(widget.subscription.copyWith(
          isActive: val,
          nextDelivery: val
              ? _calculateNextDeliveryDate(widget.subscription.frequency,
                  widget.subscription.nextDelivery!.weekday)
              : DateTime.now(), // Use current date if inactive
        ));
      },
    );
  }

  // Add to subscription button
  Widget _buildCartButton() {
    return IconButton(
      icon: const Icon(Icons.add_shopping_cart),
      onPressed: () {
        final productProvider =
            Provider.of<ProductProvider>(context, listen: false);
        final product =
            productProvider.getProductById(widget.subscription.product);

        if (product != null) {
          _askForSubscription(product);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found!')),
          );
        }
      },
    );
  }

  // Add product to subscription button
  Widget _buildAddProductButton() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductSelectionScreen(user: user),
          ),
        );
      },
      child: const Text('Add Products to Subscription'),
    );
  }

  // Show subscription options in a modal
  void _showSubscriptionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SubscriptionOptions(
          subscription: widget.subscription,
          onScheduleChange: widget.onScheduleChange,
        );
      },
    );
  }

  // Ask for subscription dialog
  void _askForSubscription(Product product) {
    int selectedFrequency = 7; // Default weekly frequency
    int selectedDay = DateTime.now().weekday; // Default to today’s weekday
    int quantity = 1; // Default quantity
    final SubscriptionService subscriptionService = SubscriptionService();
    final Subscription subscription;

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
                  product: product as String,
                  user: widget.user,
                  quantity: quantity,
                  nextDelivery: nextDelivery,
                  frequency: selectedFrequency,
                  price: product.basePrice,
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

  // Build frequency dropdown for dialog
  Widget _buildFrequencyDropdown(int selectedFrequency,
      List<int> availableFrequencies, void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Select Delivery Frequency:'),
        DropdownButton<int>(
          value: selectedFrequency,
          onChanged: (newValue) {
            setState(() {
              selectedFrequency = newValue!;
            });
          },
          items: availableFrequencies.map<DropdownMenuItem<int>>((value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value == 1 ? 'Daily' : '$value days'),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Build day dropdown for dialog
  Widget _buildDayDropdown(int selectedDay, List<String> weekDays,
      void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Select Delivery Day of the Week:'),
        DropdownButton<int>(
          value: selectedDay,
          onChanged: (newValue) {
            setState(() {
              selectedDay = newValue!;
            });
          },
          items: weekDays.asMap().entries.map<DropdownMenuItem<int>>((entry) {
            return DropdownMenuItem<int>(
              value: entry.key + 1,
              child: Text(entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Quantity control for dialog
  Widget _buildQuantityControlDialog(
      int quantity, void Function(void Function()) setState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.black),
          onPressed: () {
            setState(() {
              if (quantity > 1) quantity--;
            });
          },
        ),
        Text('$quantity',
            style: const TextStyle(color: Colors.black, fontSize: 20)),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.black),
          onPressed: () {
            setState(() {
              quantity++;
            });
          },
        ),
      ],
    );
  }
}

class SubscriptionOptions extends StatefulWidget {
  final Subscription subscription;
  final Function(Subscription) onScheduleChange;

  const SubscriptionOptions({
    super.key,
    required this.subscription,
    required this.onScheduleChange,
  });

  @override
  SubscriptionOptionsState createState() => SubscriptionOptionsState();
}

class SubscriptionOptionsState extends State<SubscriptionOptions> {
  int _frequency = 7; // Default frequency (weekly)
  final int _quantity = 1; // Default quantity
  int _selectedDay = 1; // Default to Monday
  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  // Method to ensure no extra deliveries for weekly/bi-weekly/monthly options
  bool _validateDeliveryDay() {
    if (_frequency == 1) {
      // No need to validate for daily subscriptions
      return true;
    }

    // Fetch the current day and the number of deliveries set within the period
    DateTime now = DateTime.now();
    DateTime? nextDelivery = widget.subscription.nextDelivery;

    // Ensure the selected day doesn't result in more deliveries in the same period
    if (_frequency == 7 && now.difference(nextDelivery!).inDays < 7) {
      return false;
    } else if (_frequency == 14 && now.difference(nextDelivery!).inDays < 14) {
      return false;
    } else if (_frequency == 30 && now.difference(nextDelivery!).inDays < 30) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Frequency Selection (for example, add a dropdown for selecting frequency)
        const Text('Select Delivery Frequency:'),
        DropdownButton<int>(
          value: _frequency,
          onChanged: (newValue) {
            setState(() {
              _frequency = newValue!;
            });
          },
          items: [1, 7, 14, 30].map<DropdownMenuItem<int>>((value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value == 1
                  ? 'Daily'
                  : value == 7
                      ? 'Weekly'
                      : value == 14
                          ? 'Bi-Weekly'
                          : 'Monthly'),
            );
          }).toList(),
        ),

        // Day Selection (if not Daily)
        if (_frequency > 1) ...[
          const SizedBox(height: 16),
          const Text('Select Delivery Day of the Week:'),
          DropdownButton<int>(
            value: _selectedDay,
            onChanged: (newValue) {
              setState(() {
                _selectedDay = newValue!;
              });
            },
            items:
                _weekDays.asMap().entries.map<DropdownMenuItem<int>>((entry) {
              int idx = entry.key;
              String day = entry.value;
              return DropdownMenuItem<int>(
                value: idx + 1, // Weekdays are from 1 to 7
                child: Text(day),
              );
            }).toList(),
          ),
        ],

        // Update Button
        ElevatedButton(
          onPressed: () {
            // Validate the delivery day to ensure no extra deliveries in the same period
            if (_validateDeliveryDay()) {
              widget.onScheduleChange(
                widget.subscription.copyWith(
                  frequency: _frequency,
                  quantity: _quantity,
                  isActive: widget.subscription.isActive,
                  nextDelivery: widget.subscription
                      .nextDelivery!, // Update to the next delivery date if necessary
                ),
              );
              Navigator.pop(context);
            } else {
              // Show an error if the delivery day change results in extra deliveries
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Cannot schedule more deliveries than allowed in this period.')),
              );
            }
          },
          child: const Text('Update Subscription'),
        ),
      ],
    );
  }
}