import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:grocerry/models/user.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PackagesScreen extends StatefulWidget {
  final User? user;

  const PackagesScreen({this.user, super.key});

  @override
  _PackagesScreenState createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  bool _isLoading = false;
  List<ProductSuggestion> _suggestions = [];
  final _formKey = GlobalKey<FormState>();

  // Selection options
  String? _timeOfConsumption;
  String? _weather;
  String? _cuisine;
  String? _holiday;
  bool _isSeasonal = false;
  bool _isTrending = false;
  int? _numberOfPeople;
  String? _event;
  List<String> _nature = [];
  bool _includePastPurchases = false;
  bool _includeHealthCondition = false;
  String? _selectedHealthCondition;

  final List<String> timeOptions = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final List<String> weatherOptions = ['Sunny', 'Rainy', 'Cold', 'Hot'];
  final List<String> eventOptions = ['Birthday', 'Wedding', 'Casual Gathering', 'Holiday Party'];
  final List<String> natureOptions = ['Organic', 'Gluten-Free', 'Wholemeal'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Package')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Time of Consumption'),
                  items: timeOptions.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
                  onChanged: (value) => setState(() => _timeOfConsumption = value),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Weather'),
                  items: weatherOptions.map((weather) => DropdownMenuItem(value: weather, child: Text(weather))).toList(),
                  onChanged: (value) => setState(() => _weather = value),
                ),
                _buildDynamicOptionField('Cuisine', _cuisine, (value) => _cuisine = value),
                _buildDynamicOptionField('Holiday', _holiday, (value) => _holiday = value),
                SwitchListTile(
                  title: const Text('Seasonal'),
                  value: _isSeasonal,
                  onChanged: (value) => setState(() => _isSeasonal = value),
                ),
                SwitchListTile(
                  title: const Text('Trending'),
                  value: _isTrending,
                  onChanged: (value) => setState(() => _isTrending = value),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Number of People'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() => _numberOfPeople = int.tryParse(value)),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Event'),
                  items: eventOptions.map((event) => DropdownMenuItem(value: event, child: Text(event))).toList(),
                  onChanged: (value) => setState(() => _event = value),
                ),
                const SizedBox(height: 16),
                const Text('Nature', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8.0,
                  children: natureOptions.map((nature) {
                    return ChoiceChip(
                      label: Text(nature),
                      selected: _nature.contains(nature),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _nature.add(nature);
                          } else {
                            _nature.remove(nature);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Include Past Purchases'),
                  value: _includePastPurchases,
                  onChanged: (value) => setState(() => _includePastPurchases = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Include Health Condition'),
                  value: _includeHealthCondition,
                  onChanged: (value) async {
                    if (value == true) {
                      List<String> conditions = await _fetchHealthConditions(widget.user!.id);
                      if (conditions.isNotEmpty) {
                        _selectedHealthCondition = await _showHealthConditionDialog(conditions);
                      } else {
                        _selectedHealthCondition = null;
                        value = false; // Disable if no conditions available
                      }
                    }
                    setState(() => _includeHealthCondition = value ?? false);
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generatePackageSuggestions,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Generate Suggestions'),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Suggestions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ..._suggestions.map((product) => ListTile(
                        title: Text(product.name),
                        subtitle: Text('Quantity: ${product.quantity}'),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicOptionField(String label, String? currentValue, Function(String?) onChanged) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(labelText: label),
            initialValue: currentValue,
            onChanged: onChanged,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.list),
          onPressed: () async {
            final options = label == 'Cuisine'
                ? await _getCuisineOptions()
                : await _getHolidayOptions();
            final choice = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Select $label'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('New Entry'),
                      onTap: () => Navigator.pop(context, null),
                    ),
                    ListTile(
                      title: const Text('User Specified'),
                      onTap: () => Navigator.pop(context, 'user'),
                    ),
                    ...options.map((option) => ListTile(
                          title: Text(option),
                          onTap: () => Navigator.pop(context, option),
                        )),
                  ],
                ),
              ),
            );
            if (choice == 'user') {
              final userOptions = label == 'Cuisine'
                  ? [...(widget.user!.importantCuisines ?? []), ...(widget.user!.preferredCuisines ?? [])]
                  : [...(widget.user!.importantHolidays ?? []), ...(widget.user!.customHolidays ?? [])];
              final selected = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('User $label'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: userOptions.map((option) => ListTile(
                            title: Text(option),
                            onTap: () => Navigator.pop(context, option),
                          )).toList(),
                    ),
                  ),
                ),
              );
              if (selected != null) setState(() => onChanged(selected));
            } else if (choice != null && choice != 'user') {
              setState(() => onChanged(choice));
            }
          },
        ),
      ],
    );
  }

  Future<List<String>> _getCuisineOptions() async {
    return ['Swahili', 'Italian', 'Chinese', 'Indian'];
  }

  Future<List<String>> _getHolidayOptions() async {
    return ['Christmas', 'Eid al-Fitr', 'Diwali'];
  }

  Future<List<String>> _fetchHealthConditions(String userId) async {
    // Placeholder: Replace with your actual health condition fetch logic
    return ['Diabetes', 'Hypertension', 'None']; // Example conditions
  }

  Future<String?> _showHealthConditionDialog(List<String> conditions) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Health Condition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: conditions.map((condition) => ListTile(
                  title: Text(condition),
                  onTap: () => Navigator.pop(context, condition),
                )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePackageSuggestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Fetch purchase history if selected
      List<Map<String, dynamic>> purchaseHistory = [];
      if (_includePastPurchases) {
        final purchasesSnapshot = await FirebaseFirestore.instance
            .collection('purchases')
            .where('userId', isEqualTo: widget.user!.id)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();
        purchaseHistory = purchasesSnapshot.docs.map((doc) => doc.data()).toList();
      }

      // Fetch user data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.user!.id).get();
      final userData = userDoc.data() ?? {};
      final importantCuisines = List<String>.from(userData['importantCuisines'] ?? []);
      final preferredCuisines = List<String>.from(userData['preferredCuisines'] ?? []);

      // Generate suggestions
      final suggestions = await _getChatGPTSuggestions(
        purchaseHistory,
        _includeHealthCondition ? _selectedHealthCondition : null,
        importantCuisines,
        preferredCuisines,
        timeOfConsumption: _timeOfConsumption,
        weather: _weather,
        cuisine: _cuisine,
        holiday: _holiday,
        isSeasonal: _isSeasonal,
        isTrending: _isTrending,
        numberOfPeople: _numberOfPeople,
        event: _event,
        nature: _nature,
      );

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating suggestions: $e')),
      );
    }
  }

  Future<List<ProductSuggestion>> _getChatGPTSuggestions(
    List<Map<String, dynamic>> purchases,
    String? healthCondition,
    List<String> importantCuisines,
    List<String> preferredCuisines, {
    String? timeOfConsumption,
    String? weather,
    String? cuisine,
    String? holiday,
    bool isSeasonal = false,
    bool isTrending = false,
    int? numberOfPeople,
    String? event,
    List<String>? nature,
  }) async {
    const apiKey = 'YOUR_OPENAI_API_KEY';
    const url = 'https://api.openai.com/v1/chat/completions';

    bool includeCuisines = purchases.length < 5 || importantCuisines.isNotEmpty || preferredCuisines.isNotEmpty || cuisine != null;
    final allCuisines = [...importantCuisines, ...preferredCuisines, if (cuisine != null) cuisine];

    final prompt = '''
    Based on ${purchases.isNotEmpty ? 'this purchase history: ${jsonEncode(purchases)}' : 'no purchase history'}
    ${healthCondition != null ? 'And this health condition: $healthCondition' : ''}
    ${includeCuisines && allCuisines.isNotEmpty ? 'And these preferred cuisines: ${allCuisines.join(', ')}' : ''}
    ${timeOfConsumption != null ? 'For this time of consumption: $timeOfConsumption' : ''}
    ${weather != null ? 'Considering this weather: $weather' : ''}
    ${holiday != null ? 'For this holiday: $holiday' : ''}
    ${isSeasonal ? 'Products should be seasonal' : ''}
    ${isTrending ? 'Products should be trending' : ''}
    ${numberOfPeople != null ? 'For $numberOfPeople people' : ''}
    ${event != null ? 'For this event: $event' : ''}
    ${nature != null && nature.isNotEmpty ? 'With these nature preferences: ${nature.join(', ')}' : ''}
    Suggest subscription products as a flat list in JSON format like this:
    [
      {"name": "product1", "quantity": 1},
      {"name": "product2", "quantity": 2},
      ...
    ]
    Consider purchase frequency, quantity patterns (if provided), and tailor suggestions to the provided preferences.
    ''';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = jsonDecode(data['choices'][0]['message']['content']) as List;
      return content.map((item) => ProductSuggestion.fromJson(item)).toList();
    } else {
      throw Exception('Failed to get ChatGPT response: ${response.statusCode}');
    }
  }
}

class ProductSuggestion {
  final String name;
  final int quantity;

  ProductSuggestion({required this.name, required this.quantity});

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) {
    return ProductSuggestion(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
    );
  }
}
