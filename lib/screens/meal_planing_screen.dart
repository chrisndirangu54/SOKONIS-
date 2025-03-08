import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/screens/health_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/cart_provider.dart';
import 'package:grocerry/providers/order_provider.dart';
import 'package:grocerry/services/chatgpt_service.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:grocerry/services/recipe_service.dart';
import 'package:grocerry/services/ml_service.dart';
import 'package:provider/provider.dart';

class MealPlanningScreen extends StatefulWidget {
  final User user;

  const MealPlanningScreen({super.key, required this.user});

  @override
  MealPlanningScreenState createState() => MealPlanningScreenState();
}

class MealPlanningScreenState extends State<MealPlanningScreen> {
  final ChatGPTService _chatGPTService = ChatGPTService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RecipeService _recipeService = RecipeService();
  final MLService _mlService = MLService();
  final HealthConditionService _healthConditionService = HealthConditionService();
  Variety? selectedVariety;
  bool _isLoading = false;
  List<GroceryItem> _linkedProducts = [];
  List<Meal> _weeklyMeals = [];
  List<String> recipeSuggestions = [];
  Product? product;
  late int quantity = 1;
  late StreamSubscription<double?>? _discountedPriceSubscription;
  int? _defaultNumberOfPeople;
  List<Meal> mealRecommendations = [];
  double? discountedPrice;

  @override
  void initState() {
    super.initState();
    _loadWeeklyMealPlan();
    _recommendMeals(widget.user.id);
    _loadMealRecommendations();
    product ??= Product(name: 'Sample', basePrice: 0.0, varieties: [], id: 'sample', categories: [], description: 'Sample description', units: 'kg', pictureUrl: 'https://via.placeholder.com/150', discountedPrice: 0.0);
    for (var variety in product!.varieties) {
      _listenToDiscountedPriceStream(variety.discountedPriceStream);
    }
    if (product != null) {
      _discountedPriceSubscription = product!.discountedPriceStream2?.listen(
        (price) {
          setState(() {
            discountedPrice = price;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _discountedPriceSubscription?.cancel();
    super.dispose();
  }

  void _listenToDiscountedPriceStream(Stream<Map<String, double?>?>? stream) {
    if (stream != null) {
      stream.listen((newPrice) {
        setState(() {
          discountedPrice = newPrice?['variety'];
        });
      });
    }
  }

  Future<int?> _promptForNumberOfPeople(String action, {int? defaultValue}) async {
    TextEditingController controller = TextEditingController(text: defaultValue?.toString() ?? '');
    return await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Number of People for $action'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g., 4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMealRecommendations() async {
    mealRecommendations = await _getSavedMealRecommendations();
    setState(() {});
  }

  Future<List<Meal>> _getSavedMealRecommendations() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .collection('mealRecommendations')
          .doc('current')
          .get();

      if (doc.exists) {
        final List<dynamic> mealsData = doc.data()!['meals'];
        return mealsData.map((mealMap) => Meal.fromMap(mealMap)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading meal recommendations: $e');
      return [];
    }
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
          .doc(widget.user.id)
          .collection('mealPlans')
          .doc(weekIdentifier)
          .get();

      if (doc.exists) {
        List<dynamic> mealsData = doc.data()!['meals'];
        _weeklyMeals = mealsData.map((mealMap) => Meal.fromMap(mealMap)).toList();
        _defaultNumberOfPeople = doc.data()!['numberOfPeople'] as int?;
      } else {
        _weeklyMeals = _initializeEmptyWeeklyMeals();
      }
    } catch (e) {
      _weeklyMeals = _initializeEmptyWeeklyMeals();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateGroceryList() async {
    int? numberOfPeople = await _promptForNumberOfPeople('Grocery List', defaultValue: _defaultNumberOfPeople);
    if (numberOfPeople == null) return;

    String allMeals = _weeklyMeals.map((meal) {
      return '${meal.breakfast}, ${meal.lunch}, ${meal.dinner}';
    }).join(', ');

    final holidays = widget.user.importantHolidays ?? [];
    final customHolidays = widget.user.customHolidays ?? [];
    final cuisines = widget.user.importantCuisines ?? [];
    final preferredCuisines = widget.user.preferredCuisines ?? [];
    final purchaseHistory = await _fetchPurchaseHistory(widget.user.id);
    final frequentlyBought = await _extractFrequentProducts(purchaseHistory);
    final dynamicHolidays = await _fetchDynamicHolidaysForWeek(DateTime.now());

    String context = "Generate ingredients for meal plan: $allMeals. ";
    final allHolidays = [...holidays, ...customHolidays, ...dynamicHolidays.keys];
    if (allHolidays.isNotEmpty) {
      context += "Consider holidays: ${allHolidays.join(', ')} (Kenyan, Hindu, Muslim, custom). ";
    }
    if (cuisines.isNotEmpty) {
      context += "Focus on Kenyan cuisines: ${cuisines.join(', ')}. ";
    }
    if (preferredCuisines.isNotEmpty) {
      context += "Incorporate cuisines: ${preferredCuisines.join(', ')}. ";
    }
    if (frequentlyBought.isNotEmpty) {
      context += "Use frequently bought: ${frequentlyBought.join(', ')}. ";
    }
    if (numberOfPeople != null) {
      context += "Scale ingredient quantities for $numberOfPeople people. ";
    }

    try {
      final ingredients = await _chatGPTService.generateIngredients(context);
      await _fetchProductsMatchingIngredients(ingredients, numberOfPeople);
      await _saveGroceryList(ingredients, numberOfPeople);
    } catch (e) {
      print('Error generating grocery list: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPurchaseHistory(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching purchase history: $e');
      return [];
    }
  }

  Future<List<String>> _extractFrequentProducts(List<Map<String, dynamic>> purchaseHistory) async {
    final productCounts = <String, int>{};
    for (var order in purchaseHistory) {
      final productId = order['productId'] as String?;
      if (productId != null) {
        productCounts[productId] = (productCounts[productId] ?? 0) + 1;
      }
    }

    final topProducts = productCounts.entries
        .toList()
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((e) => e.key)
        .toList();

    final productNames = <String>[];
    for (var productId in topProducts) {
      final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (doc.exists) {
        productNames.add(doc.data()!['name'] as String? ?? productId);
      }
    }
    return productNames;
  }

  Future<Map<String, DateTime>> _fetchDynamicHolidaysForWeek(DateTime currentDate) async {
    final weekBefore = currentDate.subtract(const Duration(days: 7));
    try {
      final response = await http.get(
        Uri.parse('https://newsapi.org/v2/everything?q=holiday+announcement+2025+Muslim+Easter+Chinese+American&from=${weekBefore.toIso8601String().split('T')[0]}&to=${currentDate.toIso8601String().split('T')[0]}&apiKey=YOUR_NEWSAPI_KEY'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final holidays = <String, DateTime>{};
        for (var article in data['articles']) {
          final title = article['title'].toString().toLowerCase();
          final pubDate = DateTime.parse(article['publishedAt']);
          if (title.contains('eid al-fitr')) holidays['Eid al-Fitr'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('eid al-adha')) holidays['Eid al-Adha'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('ashura')) holidays['Ashura'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('easter sunday')) holidays['Easter Sunday'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('good friday')) holidays['Good Friday'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('easter monday')) holidays['Easter Monday'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('chinese new year')) holidays['Chinese New Year'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('thanksgiving')) holidays['Thanksgiving'] = pubDate.add(const Duration(days: 7));
          else if (title.contains('independence day') && title.contains('usa')) holidays['Independence Day (USA)'] = pubDate.add(const Duration(days: 7));
        }
        return holidays.isNotEmpty ? holidays : await _fetchFallbackDynamicHolidays();
      }
    } catch (e) {
      print('Error fetching dynamic holidays: $e');
    }
    return await _fetchFallbackDynamicHolidays();
  }

  Future<Map<String, DateTime>> _fetchFallbackDynamicHolidays() async {
    final now = DateTime.now();
    return {
      'Eid al-Fitr': DateTime(now.year, 3, 31),
      'Eid al-Adha': DateTime(now.year, 6, 7),
      'Ashura': DateTime(now.year, 7, 15),
      'Easter Sunday': DateTime(now.year, 4, 12),
      'Good Friday': DateTime(now.year, 4, 10),
      'Easter Monday': DateTime(now.year, 4, 13),
      'Chinese New Year': DateTime(now.year, 2, 1),
      'Thanksgiving': DateTime(now.year, 11, 28),
      'Independence Day (USA)': DateTime(now.year, 7, 4),
    };
  }

  Future<DateTime?> _parseHoliday(String holiday) async {
    final now = DateTime.now();
    final staticHolidays = {
      'new year\'s day': DateTime(now.year, 1, 1),
      'labour day': DateTime(now.year, 5, 1),
      'madaraka day': DateTime(now.year, 6, 1),
      'mashujaa day': DateTime(now.year, 10, 20),
      'jamhuri day': DateTime(now.year, 12, 12),
      'christmas day': DateTime(now.year, 12, 25),
      'boxing day': DateTime(now.year, 12, 26),
      'holi': DateTime(now.year, 3, 14),
      'diwali': DateTime(now.year, 10, 20),
      'raksha bandhan': DateTime(now.year, 8, 19),
      'navratri': DateTime(now.year, 10, 3),
    };

    final lowerHoliday = holiday.toLowerCase();
    if (staticHolidays.containsKey(lowerHoliday)) {
      return staticHolidays[lowerHoliday];
    }

    if (holiday.contains(': ')) {
      final parts = holiday.split(': ');
      try {
        return DateTime.parse(parts[1]);
      } catch (e) {
        print('Error parsing custom holiday date: $e');
      }
    }

    final dynamicHolidays = await _fetchDynamicHolidaysForWeek(now);
    if (dynamicHolidays.containsKey(holiday)) {
      return dynamicHolidays[holiday];
    }

    return null;
  }

  String _getWeekIdentifier(DateTime date) {
    int weekNumber = ((date.dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W$weekNumber';
  }

  List<Meal> _initializeEmptyWeeklyMeals() {
    List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.map((day) => Meal(day: day)).toList();
  }

  Future<void> _saveWeeklyMealPlan() async {
    int? numberOfPeople = await _promptForNumberOfPeople('Meal Plan', defaultValue: _defaultNumberOfPeople);
    if (numberOfPeople == null) return;

    setState(() {
      _isLoading = true;
      _defaultNumberOfPeople = numberOfPeople;
    });

    try {
      DateTime now = DateTime.now();
      String weekIdentifier = _getWeekIdentifier(now);

      List<Map<String, dynamic>> mealsData = _weeklyMeals.map((meal) => meal.toMap()).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .collection('mealPlans')
          .doc(weekIdentifier)
          .set({
        'meals': mealsData,
        'numberOfPeople': numberOfPeople,
      });

      await _generateGroceryList();
    } catch (e) {
      print('Error saving meal plan: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProductsMatchingIngredients(String ingredients, int numberOfPeople) async {
    List<String> ingredientList = ingredients.split(', ').map((e) => e.trim()).toList();
    List<GroceryItem> linkedProducts = [];

    for (String ingredient in ingredientList) {
      // Parse quantity and name (e.g., "10kg rice" -> {quantity: 10, unit: "kg", name: "rice"})
      final match = RegExp(r'(\d+\.?\d*)([a-zA-Z]+)?\s*(.*)').firstMatch(ingredient);
      double? quantity = match != null ? double.tryParse(match.group(1)!) : null;
      String? unit = match?.group(2);
      String name = match?.group(3) ?? ingredient;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: name)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          Product product = Product.fromFirestore(doc: doc);
          linkedProducts.add(GroceryItem(
            name: product.name,
            price: product.basePrice,
            product: product,
            suggestedQuantity: quantity?.toInt(), // Store suggested quantity
            unit: unit, // Store unit (e.g., "kg")
          ));
        }
      }
    }

    setState(() {
      _linkedProducts = linkedProducts;
    });
  }

  Future<void> _saveGroceryList(String ingredients, int numberOfPeople) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .collection('groceryLists')
          .add({
        'ingredients': ingredients.split(', ').map((e) => e.trim()).toList(),
        'createdAt': DateTime.now(),
        'numberOfPeople': numberOfPeople,
      });
    } catch (e) {
      print('Error saving grocery list: $e');
    }
  }

  Future<void> _fetchTodaysGroceryList() async {
    int? numberOfPeople = await _promptForNumberOfPeople('Today\'s Grocery List', defaultValue: _defaultNumberOfPeople);
    if (numberOfPeople == null) return;

    final now = DateTime.now();
    final currentDayOfWeek = now.weekday;

    final todayMeals = _weeklyMeals[currentDayOfWeek - 1];
    List<String> mealsToday = [];
    if (todayMeals.breakfast.isNotEmpty) mealsToday.add(todayMeals.breakfast);
    if (todayMeals.lunch.isNotEmpty) mealsToday.add(todayMeals.lunch);
    if (todayMeals.dinner.isNotEmpty) mealsToday.add(todayMeals.dinner);

    String allMeals = mealsToday.join(', ');
    String context = "Generate ingredients for today's meals: $allMeals. ";
    if (numberOfPeople != null) {
      context += "Scale ingredient quantities for $numberOfPeople people. ";
    }

    try {
      final ingredients = await _chatGPTService.generateIngredients(context);
      await _fetchProductsMatchingIngredients(ingredients, numberOfPeople);
      await _saveGroceryList(ingredients, numberOfPeople);
    } catch (e) {
      print('Error generating grocery list for today: $e');
    }
  }

  void _askForSubscription(Product product, Variety? variety, {int? suggestedQuantity}) {
    int selectedFrequency = 7;
    int selectedDay = DateTime.now().weekday;
    final List<int> availableFrequencies = [1, 7, 14, 30];
    final List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    int quantity = suggestedQuantity ?? _defaultNumberOfPeople ?? 1; // Use ChatGPT suggestion or fallback

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Subscribe for Auto-Replenishment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Would you like to subscribe to auto-replenish this ingredient?'),
              const SizedBox(height: 16),
              const Text('Select Delivery Frequency:'),
              DropdownButton<int>(
                value: selectedFrequency,
                onChanged: (newValue) => setState(() => selectedFrequency = newValue!),
                items: availableFrequencies.map((value) => DropdownMenuItem<int>(
                  value: value,
                  child: Text(value == 1 ? 'Daily' : '$value days'),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Select Delivery Day of the Week:'),
              DropdownButton<int>(
                value: selectedDay,
                onChanged: (newValue) => setState(() => selectedDay = newValue!),
                items: weekDays.asMap().entries.map((entry) => DropdownMenuItem<int>(
                  value: entry.key + 1,
                  child: Text(entry.value),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Select Quantity:'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() => quantity = quantity > 1 ? quantity - 1 : 1),
                  ),
                  Text('$quantity', style: const TextStyle(fontSize: 20)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => quantity++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nextDeliveryDate = _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                final subscription = Subscription(
                  product: product,
                  user: widget.user,
                  quantity: quantity,
                  nextDelivery: nextDeliveryDate,
                  frequency: selectedFrequency,
                  variety: variety!,
                  price: product.basePrice,
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

  DateTime _calculateNextDeliveryDate(int frequency, int selectedDay) {
    DateTime now = DateTime.now();
    DateTime nextDelivery = now;

    while (nextDelivery.weekday != selectedDay) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }

    if (frequency > 1) {
      nextDelivery = nextDelivery.add(Duration(days: frequency));
    }

    return nextDelivery;
  }

  Future<void> _recommendMeals(String userId) async {
    int? numberOfPeople = await _promptForNumberOfPeople('Meal Recommendations', defaultValue: _defaultNumberOfPeople);
    if (numberOfPeople == null) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    bool hasHealthCondition = await _checkHealthConditionSelected(userId);

    if (!hasHealthCondition) {
      bool? wantsToSelectCondition = await _askToSelectHealthCondition();
      if (wantsToSelectCondition == true) {
        List<String> conditions = await _healthConditionService.fetchHealthConditions(userId);
        if (conditions.isNotEmpty) {
          String? selectedCondition = await _showHealthConditionSelectionDialog(conditions);
          if (selectedCondition != null) {
            _healthConditionService.updateSelectedHealthCondition(selectedCondition);
            _proceedWithMealRecommendations(userId, selectedCondition, numberOfPeople);
          } else {
            _proceedWithMealRecommendations(userId, null, numberOfPeople);
          }
        } else {
          _proceedWithMealRecommendations(userId, null, numberOfPeople);
        }
      } else {
        _proceedWithMealRecommendations(userId, null, numberOfPeople);
      }
    } else {
      _healthConditionService.healthConditionStream.listen((selectedHealthCondition) async {
        _proceedWithMealRecommendations(userId, selectedHealthCondition, numberOfPeople);
      });
    }
  }

  Future<bool> _checkHealthConditionSelected(String userId) async {
    return await _healthConditionService.healthConditionStream
            .firstWhere((condition) => condition != null, orElse: () => '') !=
        '';
  }

  Future<bool?> _askToSelectHealthCondition() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Health Condition?'),
          content: const Text('Would you like to select a health condition for personalized meal recommendations?'),
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

  Future<String?> _showHealthConditionSelectionDialog(List<String> conditions) async {
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
                        onTap: () => Navigator.pop(context, condition),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _proceedWithMealRecommendations(String userId, String? healthCondition, int numberOfPeople) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final pastPurchases = await orderProvider.getPastPurchases(userId);

    final recommendations = await _mlService.recommendMeals(
      pastPurchases.cast<String>(),
      numberOfPeople,
      healthCondition!,

    );

    await _saveMealRecommendations(recommendations, numberOfPeople);
    setState(() {
      mealRecommendations = recommendations.map((meal) => Meal(
        day: meal['day'] ?? 'Unknown',
        breakfast: meal['breakfast'] ?? '',
        lunch: meal['lunch'] ?? '',
        dinner: meal['dinner'] ?? '',
      )).toList();
    });
  }

  Future<void> _saveMealRecommendations(List<Map<String, dynamic>> recommendations, int numberOfPeople) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .collection('mealRecommendations')
        .doc('current')
        .set({
      'meals': recommendations,
      'numberOfPeople': numberOfPeople,
    });
  }

  void _suggestRecipesBasedOnPantry() async {
    int? numberOfPeople = await _promptForNumberOfPeople('Pantry Recipes', defaultValue: _defaultNumberOfPeople);
    if (numberOfPeople == null) return;

    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .collection('orders')
        .where('orderDate', isGreaterThan: twoWeeksAgo)
        .get();

    final orderItems = ordersSnapshot.docs
        .expand((doc) => List<String>.from(doc['items'] as List))
        .toList();

    final recipes = await _recipeService.getRecipesByPantryItems(
      orderItems,
      numberOfPeople: numberOfPeople,
    );

    setState(() {
      recipeSuggestions = recipes;
    });
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
                  Navigator.of(context).pop();
                  _recommendMeals(widget.user.id);
                },
              ),
              ListTile(
                title: const Text('Random Meal'),
                onTap: () async {
                  int? numberOfPeople = await _promptForNumberOfPeople('Random Meal', defaultValue: _defaultNumberOfPeople);
                  if (numberOfPeople == null) return;
                  Navigator.of(context).pop();
                  final recipes = await _recipeService.getRandomMeal(
                    numberOfPeople: numberOfPeople,
                  );
                  setState(() {
                    recipeSuggestions = recipes;
                  });
                },
              ),
              ListTile(
                title: const Text('Your Own Ingredients'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final userInput = await _getUserIngredientsInput(context);
                  if (userInput != null && userInput.isNotEmpty) {
                    int? numberOfPeople = await _promptForNumberOfPeople('Custom Ingredients Recipes', defaultValue: _defaultNumberOfPeople);
                    if (numberOfPeople == null) return;
                    final recipes = await _recipeService.getRecipesByPantryItems(
                      userInput.split(', ').map((e) => e.trim()).toList(),
                      numberOfPeople: numberOfPeople,
                    );
                    setState(() {
                      recipeSuggestions = recipes;
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Suggest a Meal'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final userSuggestions = await _getUserMealInput(context);
                  if (userSuggestions != null && userSuggestions.isNotEmpty) {
                    int? numberOfPeople = await _promptForNumberOfPeople('Suggested Meal', defaultValue: _defaultNumberOfPeople);
                    if (numberOfPeople == null) return;
                    final recipes = await _recipeService.getUserSuggestedMeals(
                      userSuggestions.split(', ').map((e) => e.trim()).toList(),
                      numberOfPeople: numberOfPeople,
                    );
                    setState(() {
                      recipeSuggestions = recipes;
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Today\'s Grocery List'),
                onTap: () async {
                  Navigator.of(context).pop();
                  _fetchTodaysGroceryList();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
      builder: (context) => AlertDialog(
        title: const Text('Enter Your Ingredients'),
        content: TextField(
          controller: ingredientsController,
          decoration: const InputDecoration(hintText: 'e.g., tomatoes, chicken, rice'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Submit'),
            onPressed: () => Navigator.of(context).pop(ingredientsController.text),
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserMealInput(BuildContext context) async {
    TextEditingController mealController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggest a Meal'),
        content: TextField(
          controller: mealController,
          decoration: const InputDecoration(hintText: 'e.g., pasta, salad, curry'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Submit'),
            onPressed: () => Navigator.of(context).pop(mealController.text),
          ),
        ],
      ),
    );
  }

  void _editMeal(int index, Meal meal) async {
    TextEditingController breakfastController = TextEditingController(text: meal.breakfast);
    TextEditingController lunchController = TextEditingController(text: meal.lunch);
    TextEditingController dinnerController = TextEditingController(text: meal.dinner);

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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createOrEditMealPlan() async {
    bool reset = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create/Edit Meal Plan'),
        content: const Text('Would you like to create a new meal plan for this week? This will reset the current plan.'),
        actions: [
          TextButton(
            onPressed: () {
              reset = true;
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Planning & Grocery List')),
        body: const Center(child: CircularProgressIndicator()),
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
            TextFormField(
              decoration: const InputDecoration(labelText: 'Default Number of People'),
              keyboardType: TextInputType.number,
              initialValue: _defaultNumberOfPeople?.toString(),
              validator: (value) => value!.isEmpty || int.parse(value) <= 0 ? 'Enter a valid number' : null,
              onChanged: (value) {
                setState(() {
                  _defaultNumberOfPeople = int.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16),
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
                              final groceryItem = _linkedProducts[index];
                              return ListTile(
                                title: Text(groceryItem.name),
                                subtitle: Text('Price: \$${groceryItem.price.toStringAsFixed(2)}${groceryItem.suggestedQuantity != null ? ' (Suggested: ${groceryItem.suggestedQuantity} ${groceryItem.unit ?? ''})' : ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        int? numberOfPeople = await _promptForNumberOfPeople('Add to Cart', defaultValue: _defaultNumberOfPeople);
                                        if (numberOfPeople == null) return;
                                        cartProvider.addItem(
                                          groceryItem.product,
                                          widget.user,
                                          selectedVariety,
                                          numberOfPeople,
                                          '',
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Added to cart')),
                                        );
                                      },
                                      child: const Text('Add to Cart'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _askForSubscription(
                                        groceryItem.product,
                                        null,
                                        suggestedQuantity: groceryItem.suggestedQuantity,
                                      ),
                                      child: const Text('Subscribe'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : const Text('No grocery items generated.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _suggestRecipesBasedOnPantry,
              child: const Text('Suggest Recipes from Pantry'),
            ),
            ElevatedButton(
              onPressed: _suggestRecipesBasedOnGroceryList,
              child: const Text('Generate Recipes'),
            ),
            const SizedBox(height: 16),
            if (mealRecommendations.isNotEmpty)
              Text('Recommended Meals: ${mealRecommendations.map((m) => "${m.day}: ${m.breakfast}, ${m.lunch}, ${m.dinner}").join('; ')}'),
            if (recipeSuggestions.isNotEmpty)
              Text('Recipe Suggestions: ${recipeSuggestions.join(', ')}'),
          ],
        ),
      ),
    );
  }
}

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

class GroceryItem {
  String name;
  double price;
  Product product;
  int? suggestedQuantity; // Added to store ChatGPT-suggested quantity
  String? unit; // Added to store unit (e.g., "kg")

  GroceryItem({
    required this.name,
    required this.price,
    required this.product,
    this.suggestedQuantity,
    this.unit,
  });
}

extension DateTimeExtension on DateTime {
  int get dayOfYear {
    final yearStart = DateTime(year, 1, 1);
    final diff = difference(yearStart);
    return diff.inDays + 1;
  }
}