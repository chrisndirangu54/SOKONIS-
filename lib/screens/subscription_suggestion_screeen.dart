import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/health_screen.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

class SubscriptionSuggestionScreen extends StatefulWidget {
  final User user;

  const SubscriptionSuggestionScreen({super.key, required this.user});

  @override
  State<SubscriptionSuggestionScreen> createState() =>
      _SubscriptionSuggestionScreenState();
}

class _SubscriptionSuggestionScreenState
    extends State<SubscriptionSuggestionScreen> {
  Map<String, List<ProductSuggestion>> _suggestions = {
    'Daily': [],
    'Weekly': [],
    'Bi-weekly': [],
    'Monthly': [],
  };
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final List<int> _frequencies = [1, 7, 14, 30]; // Days for each frequency
  final List<String> _frequencyTitles = [
    'Daily',
    'Weekly',
    'Bi-weekly',
    'Monthly'
  ];
  final HealthConditionService _healthConditionService =
      HealthConditionService(); // Assuming this exists

  @override
  void initState() {
    super.initState();
    _generateSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestions() async {
    setState(() => _isLoading = true);

    try {
      // Check if a health condition is already selected
      bool hasHealthCondition =
          await _checkHealthConditionSelected(widget.user.id);

      String? selectedHealthCondition;
      if (!hasHealthCondition) {
        bool? wantsToSelectCondition = await _askToSelectHealthCondition();
        if (wantsToSelectCondition == true) {
          List<String> conditions = await _healthConditionService
              .fetchHealthConditions(widget.user.id);
          if (conditions.isNotEmpty) {
            selectedHealthCondition =
                await _showHealthConditionSelectionDialog(conditions);
            if (selectedHealthCondition != null) {
              _healthConditionService
                  .updateSelectedHealthCondition(selectedHealthCondition);
            }
          }
        }
      } else {
        selectedHealthCondition =
            await _healthConditionService.healthConditionStream.firstWhere(
          (condition) => condition != null,
          orElse: () => '',
        );
      }

      // Fetch purchase history
      final purchasesSnapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .where('userId', isEqualTo: widget.user.id)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> purchaseHistory =
          purchasesSnapshot.docs.map((doc) => doc.data()).toList();

      // Generate suggestions with or without health condition
      final suggestions = await _getChatGPTSuggestions(
          purchaseHistory, selectedHealthCondition);

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating suggestions: $e')),
        );
      }
    }
  }

  Future<bool> _checkHealthConditionSelected(String userId) async {
    return await _healthConditionService.healthConditionStream.firstWhere(
          (condition) => condition != null,
          orElse: () => '',
        ) !=
        '';
  }

  Future<bool?> _askToSelectHealthCondition() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Health Condition?'),
          content: const Text(
              'Would you like to select a health condition for personalized subscription suggestions?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showHealthConditionSelectionDialog(
      List<String> conditions) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Health Condition'),
          content: SingleChildScrollView(
            child: Column(
              children: conditions
                  .map((condition) => ListTile(
                        title: Text(condition),
                        onTap: () {
                          Navigator.pop(context, condition);
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, List<ProductSuggestion>>> _getChatGPTSuggestions(
      List<Map<String, dynamic>> purchases, String? healthCondition) async {
    const apiKey = 'YOUR_OPENAI_API_KEY';
    const url = 'https://api.openai.com/v1/chat/completions';

    final prompt = '''
    Based on this purchase history: ${jsonEncode(purchases)}
    ${healthCondition != null ? 'And this health condition: $healthCondition' : ''}
    Suggest subscription products and their frequencies (Daily, Weekly, Bi-weekly, Monthly).
    Group them by frequency and return in JSON format like this:
    {
      "Daily": [{"name": "product1", "quantity": 1}, ...],
      "Weekly": [{"name": "product2", "quantity": 2}, ...],
      "Bi-weekly": [{"name": "product3", "quantity": 1}, ...],
      "Monthly": [{"name": "product4", "quantity": 3}, ...]
    }
    Consider purchase frequency, quantity patterns, and ${healthCondition != null ? 'tailor suggestions to the health condition' : 'general preferences'}.
    ''';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = jsonDecode(data['choices'][0]['message']['content']);
      return content.map((key, value) => MapEntry(
            key,
            (value as List)
                .map((item) => ProductSuggestion.fromJson(item))
                .toList(),
          ));
    } else {
      throw Exception('Failed to get ChatGPT response: ${response.statusCode}');
    }
  }

  Future<void> _addProduct(String frequency) async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final productData =
            querySnapshot.docs.first.data() as Map<String, dynamic>;
        final product =
            Product.fromMap(productData); // Assuming Product.fromMap exists
        setState(() {
          _suggestions[frequency]!.add(ProductSuggestion(
            name: product.name,
            quantity: 1,
            product: product,
          ));
        });
        _searchController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  void _removeProduct(String frequency, int index) {
    setState(() {
      _suggestions[frequency]!.removeAt(index);
    });
  }

  void _updateQuantity(String frequency, int index, int newQuantity) {
    setState(() {
      if (newQuantity >= 1) {
        _suggestions[frequency]![index] = ProductSuggestion(
          name: _suggestions[frequency]![index].name,
          quantity: newQuantity,
          product: _suggestions[frequency]![index].product,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Suggestions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _frequencyTitles.length,
              itemBuilder: (context, index) {
                final frequency = _frequencyTitles[index];
                final suggestions = _suggestions[frequency]!;

                return ExpansionTile(
                  title: Text(frequency),
                  subtitle: Text('${suggestions.length} suggested items'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search products to add',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _addProduct(frequency),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: suggestions.length,
                            itemBuilder: (context, suggestionIndex) {
                              final suggestion = suggestions[suggestionIndex];
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  Variety? selectedVariety = suggestion
                                              .product?.varieties.isNotEmpty ??
                                          false
                                      ? suggestion.product!.varieties.first
                                      : null;

                                  return ExpansionTile(
                                    leading: _buildLeadingImage(
                                        suggestion, selectedVariety),
                                    title: Text(suggestion.name),
                                    subtitle: Row(
                                      children: [
                                        Text('Qty: ${suggestion.quantity}'),
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => setState(() =>
                                              _updateQuantity(
                                                  frequency,
                                                  suggestionIndex,
                                                  suggestion.quantity - 1)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => setState(() =>
                                              _updateQuantity(
                                                  frequency,
                                                  suggestionIndex,
                                                  suggestion.quantity + 1)),
                                        ),
                                        Text(
                                            'Price: \$${_getPrice(suggestion, selectedVariety)}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle),
                                      onPressed: () => _removeProduct(
                                          frequency, suggestionIndex),
                                    ),
                                    children: [
                                      if (suggestion
                                              .product?.varieties.isNotEmpty ??
                                          false)
                                        SizedBox(
                                          height: 150,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: suggestion
                                                .product!.varieties.length,
                                            itemBuilder:
                                                (context, varietyIndex) {
                                              final variety = suggestion
                                                  .product!
                                                  .varieties[varietyIndex];
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      selectedVariety = variety;
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 120,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color:
                                                            selectedVariety ==
                                                                    variety
                                                                ? Colors.green
                                                                : Colors.grey,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        variety.imageUrl != null
                                                            ? Image.network(
                                                                variety
                                                                    .imageUrl!,
                                                                width: 80,
                                                                height: 80,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder: (context,
                                                                        error,
                                                                        stackTrace) =>
                                                                    const Icon(
                                                                        Icons
                                                                            .error_outline,
                                                                        size:
                                                                            40),
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                size: 40),
                                                        Text(
                                                          variety.name ??
                                                              'Unnamed',
                                                          textAlign:
                                                              TextAlign.center,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          '\$${variety.price.toStringAsFixed(2)}',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _subscribeToFrequency(
                                frequency, _frequencies[index]),
                            child: Text('Subscribe to $frequency'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget? _buildLeadingImage(
      ProductSuggestion suggestion, Variety? selectedVariety) {
    if (selectedVariety?.imageUrl != null) {
      return Image.network(
        selectedVariety!.imageUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.error_outline, size: 40),
      );
    } else if (suggestion.product?.pictureUrl != null) {
      return Image.network(
        suggestion.product!.pictureUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.error_outline, size: 40),
      );
    }
    return null;
  }

  String _getPrice(ProductSuggestion suggestion, Variety? selectedVariety) {
    return selectedVariety?.price.toStringAsFixed(2) ??
        suggestion.product?.basePrice.toStringAsFixed(2) ??
        'N/A';
  }

  void _subscribeToFrequency(String frequency, int defaultFrequency) {
    final suggestions = _suggestions[frequency]!;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to subscribe to')),
      );
      return;
    }

    int selectedFrequency = defaultFrequency;
    int selectedDay = DateTime.now().weekday;
    final subscriptionService = SubscriptionService();
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final availableFrequencies = [1, 7, 14, 30];
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
          title: Text('Subscribe to $frequency Suggestions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Subscribe to all ${suggestions.length} products in $frequency?'),
              _buildFrequencyDropdown(
                  selectedFrequency, availableFrequencies, setState),
              _buildDayDropdown(selectedDay, weekDays, setState),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nextDelivery =
                    _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                for (var suggestion in suggestions) {
                  // Default to first variety if available, otherwise use base product
                  final selectedVariety =
                      suggestion.product?.varieties.isNotEmpty ?? false
                          ? suggestion.product!.varieties.first
                          : null;

                  final subscription = Subscription(
                    product: suggestion.product!,
                    user: user,
                    quantity: suggestion.quantity,
                    nextDelivery: nextDelivery,
                    frequency: selectedFrequency,
                    price:
                        selectedVariety?.price ?? suggestion.product!.basePrice,
                    variety: selectedVariety!,
                  );
                  subscriptionService.addSubscription(subscription, context);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Subscribed to $frequency suggestions')),
                );
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

  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime nextDelivery = DateTime.now();
    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }
    return nextDelivery;
  }

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
}

class ProductSuggestion {
  final String name;
  final int quantity;
  final Product? product;

  ProductSuggestion({required this.name, required this.quantity, this.product});

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) {
    return ProductSuggestion(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }
}
