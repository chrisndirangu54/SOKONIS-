import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/cart_provider.dart';
import 'package:grocerry/providers/order_provider.dart';
import 'package:grocerry/screens/health_screen.dart';
import 'package:grocerry/services/chatgpt_service.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:grocerry/services/recipe_service.dart';
import 'package:grocerry/services/ml_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date handling

class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  MealPlanningScreenState createState() => MealPlanningScreenState();
}

class MealPlanningScreenState extends State<MealPlanningScreen> {
  final ChatGPTService _chatGPTService = ChatGPTService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RecipeService _recipeService = RecipeService();
  final MLService _mlService = MLService();
  Variety? selectedVariety;
  bool _isLoading = false;
  String user = 'user_id_placeholder'; // Replace with actual user ID
  late String selectedHealthCondition;
  List<GroceryItem> _linkedProducts = [];
  List<Meal> _weeklyMeals = [];
  List<String> recipeSuggestions = []; // List to store the recipe suggestions

  var quantity;

  @override
  void initState() {
    super.initState();
    _loadWeeklyMealPlan();
    _recommendMeals(user);
    _loadMealRecommendations();
  }

  List<String> mealRecommendations = [];

  Future<void> _loadMealRecommendations() async {
    mealRecommendations = await _getSavedMealRecommendations();
    setState(() {});
  }

  Future<void> _loadWeeklyMealPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime now = DateTime.now();
      String weekIdentifier = _getWeekIdentifier(now);

      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user)
          .collection('mealPlans')
          .doc(weekIdentifier)
          .get();

      if (doc.exists) {
        List<dynamic> mealsData = doc.data()!['meals'];
        _weeklyMeals =
            mealsData.map((mealMap) => Meal.fromMap(mealMap)).toList();
      } else {
        // Initialize with empty meals for the week
        _weeklyMeals = _initializeEmptyWeeklyMeals();
      }
    } catch (e) {
      // Handle error, possibly initialize empty meals
      _weeklyMeals = _initializeEmptyWeeklyMeals();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getWeekIdentifier(DateTime date) {
    // You can customize the week identifier as needed
    // Here, we'll use year and week number
    int weekNumber = ((date.dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W$weekNumber';
  }

  List<Meal> _initializeEmptyWeeklyMeals() {
    List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days.map((day) => Meal(day: day)).toList();
  }

  Future<void> _saveWeeklyMealPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime now = DateTime.now();
      String weekIdentifier = _getWeekIdentifier(now);

      List<Map<String, dynamic>> mealsData =
          _weeklyMeals.map((meal) => meal.toMap()).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .collection('mealPlans')
          .doc(weekIdentifier)
          .set({'meals': mealsData});

      // Generate ingredients and fetch linked products
      await _generateGroceryList();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateGroceryList() async {
    String allMeals = _weeklyMeals.map((meal) {
      return '${meal.breakfast}, ${meal.lunch}, ${meal.dinner}';
    }).join(', ');

    try {
      final ingredients = await _chatGPTService.generateIngredients(allMeals);
      // Fetch products matching the generated ingredients
      await _fetchProductsMatchingIngredients(ingredients);
      // Save the grocery list
      await _saveGroceryList(ingredients);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchProductsMatchingIngredients(String ingredients) async {
    List<String> ingredientList =
        ingredients.split(', ').map((e) => e.trim()).toList();
    List<GroceryItem> linkedProducts = [];

    for (String ingredient in ingredientList) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: ingredient)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          linkedProducts.add(GroceryItem(
            name: doc['name'],
            price: doc['basePrice'],
            product: doc.id,
          ));
        }
      }
    }

    setState(() {
      _linkedProducts = linkedProducts;
    });
  }

  Future<void> _saveGroceryList(String ingredients) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user)
          .collection('groceryLists')
          .add({
        'ingredients': ingredients.split(', ').map((e) => e.trim()).toList(),
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      // Handle error
    }
  }

  void _askForSubscription(product) {
    int selectedFrequency = 7; // Default to weekly
    int selectedDay = DateTime.now().weekday; // Default to today’s weekday
    final List<int> availableFrequencies = [
      1,
      7,
      14,
      30
    ]; // Daily, Weekly, Bi-weekly, Monthly
    final List<String> weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    int quantity = 1; // Default quantity

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Subscribe for Auto-Replenishment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Would you like to subscribe to auto-replenish this ingredient?'),

              // Frequency Selection
              const SizedBox(height: 16),
              const Text('Select Delivery Frequency:'),
              DropdownButton<int>(
                value: selectedFrequency,
                onChanged: (newValue) {
                  setState(() {
                    selectedFrequency = newValue!;
                  });
                },
                items: availableFrequencies
                    .map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value == 1 ? 'Daily' : '$value days'),
                  );
                }).toList(),
              ),

              // Day Selection
              const SizedBox(height: 16),
              const Text('Select Delivery Day of the Week:'),
              DropdownButton<int>(
                value: selectedDay,
                onChanged: (newValue) {
                  setState(() {
                    selectedDay = newValue!;
                  });
                },
                items: weekDays
                    .asMap()
                    .entries
                    .map<DropdownMenuItem<int>>((entry) {
                  int idx = entry.key;
                  String day = entry.value;
                  return DropdownMenuItem<int>(
                    value: idx + 1, // Weekdays are from 1 to 7
                    child: Text(day),
                  );
                }).toList(),
              ),

              // Quantity Selection
              const SizedBox(height: 16),
              const Text('Select Quantity:'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decrement Button
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.black),
                    onPressed: () {
                      setState(() {
                        if (quantity > 1) {
                          quantity--; // Decrease quantity
                        }
                      });
                    },
                  ),
                  // Quantity Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(color: Colors.black, fontSize: 20),
                    ),
                  ),
                  // Increment Button
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: () {
                      setState(() {
                        quantity++; // Increase quantity
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nextDeliveryDate =
                    _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                final subscription = Subscription(
                  product: product,
                  user: user,
                  quantity: quantity, // Adjusted quantity
                  nextDelivery: nextDeliveryDate,
                  frequency: selectedFrequency, // User-selected frequency
                  price: product.price,
                );
                _subscriptionService.addSubscription(subscription, context);
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

// Helper method to calculate the next delivery date based on frequency and selected day
  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime now = DateTime.now();
    DateTime nextDelivery = now;

    // Calculate the next delivery date based on the selected day of the week
    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }

    // Add frequency days to the next delivery date
    if (frequency > 1) {
      nextDelivery = nextDelivery.add(Duration(days: frequency));
    }

    return nextDelivery;
  }

  Future<void> _recommendMeals(String user) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final HealthConditionService healthConditionService =
        HealthConditionService();

    healthConditionService.healthConditionStream
        .listen((selectedHealthCondition) async {
      final pastPurchases = await orderProvider.getPastPurchases(user);

      final recommendations = await _mlService.recommendMeals(
        pastPurchases.cast<String>(),
        selectedHealthCondition,
      );

      // Save meal recommendations
      await _saveMealRecommendations(recommendations);

      setState(() {
        // Trigger a UI update, if necessary
      });
    });
  }

  // Helper method to save meal recommendations
  Future<void> _saveMealRecommendations(List<String> recommendations) async {
    // Example: Using SharedPreferences to store the recommendations locally
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('mealRecommendations', recommendations);
  }

  Future<List<String>> _getSavedMealRecommendations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('mealRecommendations') ?? [];
  }

  void _suggestRecipesBasedOnPantry() async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    // Fetch the user's orders from the last two weeks
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user)
        .collection('orders')
        .where('orderDate', isGreaterThan: twoWeeksAgo)
        .get();

    // Extract the list of items from all the orders
    final orderItems = ordersSnapshot.docs
        .expand((doc) => List<String>.from(doc['items'] as List))
        .toList();

    // Fetch recipes based on the pantry items
    final recipes = await _recipeService.getRecipesByPantryItems(orderItems);

    // Update the UI with the suggested recipes
    setState(() {});
  }

  void _suggestRecipesBasedOnGroceryList() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Meal Suggestion Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Recommended Meals'),
                onTap: () {
                  Navigator.of(context).pop(); // Close the dialog
                  _recommendMeals(
                      user); // Your existing method for recommended meals
                },
              ),
              ListTile(
                title: const Text('Random Meal'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  final recipes = await _recipeService.getRandomMeal();
                  setState(() {
                    recipeSuggestions =
                        recipes; // Update UI with random meal suggestions
                  });
                },
              ),
              ListTile(
                title: const Text('Your Own Ingredients'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the main dialog
                  final userInput = await _getUserIngredientsInput(
                      context); // Get user input through the dialog

                  if (userInput != null && userInput.isNotEmpty) {
                    final recipes =
                        await _recipeService.getRecipesByPantryItems(
                      userInput.split(', ').map((e) => e.trim()).toList(),
                    );

                    setState(() {
                      recipeSuggestions =
                          recipes; // Update UI with recipes based on user input
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Suggest a Meal'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the main dialog
                  final userSuggestions = await _getUserMealInput(
                      context); // Get user-suggested meal

                  if (userSuggestions != null && userSuggestions.isNotEmpty) {
                    final recipes = await _recipeService.getUserSuggestedMeals(
                      userSuggestions.split(', ').map((e) => e.trim()).toList(),
                    );

                    setState(() {
                      recipeSuggestions =
                          recipes; // Update UI with user-suggested meals
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Today\'s Grocery List'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  _fetchTodaysGroceryList(); // Call the method to fetch today's grocery list
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close the dialog
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getUserIngredientsInput(BuildContext context) async {
    TextEditingController ingredientsController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Your Ingredients'),
          content: TextField(
            controller: ingredientsController,
            decoration: const InputDecoration(
                hintText: 'e.g., tomatoes, chicken, rice'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close dialog without returning any input
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                Navigator.of(context)
                    .pop(ingredientsController.text); // Return the user input
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getUserMealInput(BuildContext context) async {
    TextEditingController mealController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Suggest a Meal'),
          content: TextField(
            controller: mealController,
            decoration:
                const InputDecoration(hintText: 'e.g., pasta, salad, curry'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close dialog without returning any input
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                Navigator.of(context)
                    .pop(mealController.text); // Return the user input
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchTodaysGroceryList() async {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday

    // Fetch today's meals based on the weekly meal plan
    final todayMeals = _weeklyMeals[
        currentDayOfWeek - 1]; // Assuming _weeklyMeals is indexed by weekday

    // Prepare a list of all meals for today
    List<String> mealsToday = [];
    if (todayMeals.breakfast != null && todayMeals.breakfast.isNotEmpty) {
      mealsToday.add(todayMeals.breakfast);
    }
    if (todayMeals.lunch != null && todayMeals.lunch.isNotEmpty) {
      mealsToday.add(todayMeals.lunch);
    }
    if (todayMeals.dinner != null && todayMeals.dinner.isNotEmpty) {
      mealsToday.add(todayMeals.dinner);
    }

    // Join meals into a single string for ingredient generation
    String allMeals = mealsToday.join(', ');

    try {
      // Generate ingredients using ChatGPT service
      final ingredients = await _chatGPTService.generateIngredients(allMeals);

      // Fetch products matching the generated ingredients
      await _fetchProductsMatchingIngredients(ingredients);

      // Save the grocery list for today
      await _saveGroceryList(ingredients);
    } catch (e) {
      // Handle error appropriately
      print('Error generating grocery list for today: $e');
    }
  }

  void _editMeal(int index, Meal meal) async {
    // Open a dialog to edit the meal
    TextEditingController breakfastController =
        TextEditingController(text: meal.breakfast);
    TextEditingController lunchController =
        TextEditingController(text: meal.lunch);
    TextEditingController dinnerController =
        TextEditingController(text: meal.dinner);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${meal.day}\'s Meals'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: breakfastController,
                decoration: const InputDecoration(labelText: 'Breakfast'),
              ),
              TextField(
                controller: lunchController,
                decoration: const InputDecoration(labelText: 'Lunch'),
              ),
              TextField(
                controller: dinnerController,
                decoration: const InputDecoration(labelText: 'Dinner'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _weeklyMeals[index] = Meal(
                  day: meal.day,
                  breakfast: breakfastController.text,
                  lunch: lunchController.text,
                  dinner: dinnerController.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _createOrEditMealPlan() async {
    // For simplicity, we'll open a dialog to confirm reset and edit
    bool reset = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create/Edit Meal Plan'),
        content: const Text(
            'Would you like to create a new meal plan for this week? This will reset the current plan.'),
        actions: [
          TextButton(
            onPressed: () {
              reset = true;
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('No')),
        ],
      ),
    );

    if (reset) {
      setState(() {
        _weeklyMeals = _initializeEmptyWeeklyMeals();
      });
      await _saveWeeklyMealPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Display loading indicator if necessary
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meal Planning & Grocery List'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planning & Grocery List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _createOrEditMealPlan,
            tooltip: 'Create/Edit Meal Plan',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Weekly Meal Plan Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Day')),
                    DataColumn(label: Text('Breakfast')),
                    DataColumn(label: Text('Lunch')),
                    DataColumn(label: Text('Dinner')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: List<DataRow>.generate(_weeklyMeals.length, (index) {
                    final meal = _weeklyMeals[index];
                    return DataRow(cells: [
                      DataCell(Text(meal.day)),
                      DataCell(Text(meal.breakfast)),
                      DataCell(Text(meal.lunch)),
                      DataCell(Text(meal.dinner)),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editMeal(index, meal),
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Grocery List Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grocery List:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _linkedProducts.isNotEmpty
                        ? ListView.builder(
                            itemCount: _linkedProducts.length,
                            itemBuilder: (context, index) {
                              final product = _linkedProducts[index];
                              return ListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                    'Price: \$${product.price.toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Decrement Button
                                    IconButton(
                                      icon: const Icon(Icons.remove,
                                          color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          if (quantity > 1) {
                                            quantity--; // Decrease quantity
                                          }
                                        });
                                      },
                                    ),
                                    // Quantity Display
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Text(
                                        '$quantity',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 20),
                                      ),
                                    ),
                                    // Increment Button
                                    IconButton(
                                      icon: const Icon(Icons.add,
                                          color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          quantity++; // Increase quantity
                                        });
                                      },
                                    ),
                                    // Add to Cart Button
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart,
                                          color: Colors.white, size: 40),
                                      onPressed: () {
                                        // Call the addItem function with the selected quantity
                                        cartProvider.addItem(
                                          product as Product,
                                          user as User,
                                          selectedVariety!, // Assuming selectedVariety is defined
                                          quantity,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  // Optionally, implement more details or actions
                                  _askForSubscription(product as String);
                                },
                              );
                            },
                          )
                        : const Text('No grocery items generated.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Additional Buttons or Information
            ElevatedButton(
              onPressed: _suggestRecipesBasedOnPantry,
              child: const Text('Suggest Recipes from Pantry'),
            ),
            // Additional Buttons or Information
            ElevatedButton(
              onPressed: _suggestRecipesBasedOnGroceryList,
              child: const Text('Generate Recipes'),
            ),
            const SizedBox(height: 16),
            // Display Recommendations if any
            if (mealRecommendations.isNotEmpty)
              Text('Recommended Meals: ${mealRecommendations.join(', ')}'),
            if (recipeSuggestions.isNotEmpty)
              Text('Recipe Suggestions: $recipeSuggestions'),
          ],
        ),
      ),
    );
  }
}

// models/meal.dart
class Meal {
  String day;
  String breakfast;
  String lunch;
  String dinner;

  Meal({
    required this.day,
    this.breakfast = '',
    this.lunch = '',
    this.dinner = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      day: map['day'] ?? '',
      breakfast: map['breakfast'] ?? '',
      lunch: map['lunch'] ?? '',
      dinner: map['dinner'] ?? '',
    );
  }
}

// models/grocery_item.dart
class GroceryItem {
  String name;
  double price;
  String product;

  GroceryItem({
    required this.name,
    required this.price,
    required this.product,
  });
}

extension DateTimeExtension on DateTime {
  int get dayOfYear {
    return int.parse(DateFormat("D").format(this));
  }
}
