import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grocerry/models/notification_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/cart_provider.dart';
import 'package:grocerry/screens/notification_screen.dart';
import 'package:grocerry/screens/offers_page.dart';
import 'package:lottie/lottie.dart';
import 'package:marquee/marquee.dart';

import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/models/offer.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/admin_add_product_screen.dart';
import 'package:grocerry/screens/admin_dashboard_screen.dart';
import 'package:grocerry/screens/admin_offers_screen.dart';
import 'package:grocerry/screens/cart_screen.dart';
import 'package:grocerry/screens/login_screen.dart';
import 'package:grocerry/screens/pending_deliveries_screen.dart';
import 'package:grocerry/screens/product_screen.dart';
import 'package:grocerry/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/product_provider.dart';
import '../providers/offer_provider.dart';
import '../utils.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'dart:math';
import 'package:http/http.dart' as http; // For HTTP requests

import 'package:grocerry/services/ai_service.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../services/notification_service.dart'; // Adjust path as needed
import 'package:fuzzy/fuzzy.dart'; // Ensure you have the fuzzy package imported

class HomeScreen extends StatefulWidget {
  final Product? product; // Change to Product type

  const HomeScreen({super.key, this.product});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<String> categories = []; // Track if initial suggestions are provided.
// Convert your List<Product> into a Map<String, List<Product>> grouped by category
  late Map<String, List<Product>>? categoryProducts;  
  List<Product> complementaryProducts = [];
  final cs.CarouselSliderController controller = cs.CarouselSliderController();
  List<Product> favorites = [];
  List<Product> filteredProducts = [];
  List<Product> filteredProducts2 = [];
  // Define all possible subcategories here or load them dynamically
  final List<String> subcategories = [];
  final List<Product> _genomicAlternatives = [];
  bool? isSearching = false;
  List<Product> nearbyUsersBought = [];
  List<NotificationModel>? notifications = [];
  List<Offer> offers = [];
  List<Product> predictedProducts = [];
  List<String> previouslySearchedProducts =
      []; // Cache for previously searched products
  String? sortBy = 'default'; // default, priceLow, priceHigh, etc.
  List<String> selectedSubcategories =
      []; // Assuming products can belong to multiple subcategories
  double? minPrice = 0.0;
  double? maxPrice = double.infinity;
  List<Product> products = [];
  List<Product> recentlyBought = [];
  TextEditingController searchController = TextEditingController();
  List<String> searchSuggestions = [];
  List<Product> seasonallyAvailable = [];
  String? selectedCategory;
  User? user;
  String? _healthBenefits;
  Product? _selectedHealthBenefitsProduct;
  Product? product;
  Timer? _autoScrollTimer;
  Timer? _debounce;
  bool _hasInitialSuggestions = false;
  bool? _isFlipped = false;
  bool _isPressed = false;
  final NotificationService _notificationService = NotificationService();
  late OfferProvider _offerProvider;
  late ProductProvider _productProvider;
  int? _unreadNotificationsCount = 0;
  final UserAnalyticsService _userAnalyticsService = UserAnalyticsService();
  late UserProvider _userProvider;
  double? discountedPrice;
  late StreamSubscription<double?>? _discountedPriceSubscription;
// Define these in your state class
  final ScrollController _scrollController = ScrollController();
  final ScrollController _hintScrollController = ScrollController();
  double _appBarBottomHeight = 100.0;
  int? _currentIndex = 0;
  String? _dynamicJourney;
  String? _joke;
  bool? _isLoading = false;
  Stream<Map<String, double?>?>? discountedPriceStream;
  Stream<double?>? discountedPriceStream2;
  // OpenAI API details
  final String? apiKey = 'YOUR_OPENAI_API_KEY';
  final String? apiUrl = 'https://api.openai.com/v1/chat/completions';
  late DateTime? viewStartTime;
  // StreamController for predicted products
  final StreamController<List<Product>> _predictedProductsController =
      StreamController<List<Product>>.broadcast();
  Stream<List<Product>> get predictedProductsStream =>
      _predictedProductsController.stream;
  Product? _selectedJourneyProduct;
  Offer? offer;
  Variety? selectedVariety;
// Initialize in your state class
  final _searchDebouncer = _Debouncer();
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize providers
    _productProvider = Provider.of<ProductProvider>(context);
    _offerProvider = Provider.of<OfferProvider>(context);
    _userProvider = Provider.of<UserProvider>(context);

    // Perform initial setup after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProducts();
      _initializeOffers();
    });

    // Add a listener to filter products based on search
    searchController.addListener(_filterProducts);
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startHintAnimation();

    // Check if widget.product is not null before accessing its properties
    if (widget.product != null) {
      _discountedPriceSubscription =
          widget.product!.discountedPriceStream2?.listen(
        (price) {
          setState(() {
            discountedPriceStream2 = price as Stream<double?>?;
          });
        },
      );

      // Check if product has varieties before iterating
      if (widget.product!.varieties != null) {
        for (var variety in widget.product!.varieties!) {
          if (variety.discountedPriceStream != null) {
            _listenToDiscountedPriceStream2(variety.discountedPriceStream!);
          }
        }
      }
    } else {
      print("Product is null in HomeScreen initState");
    }

    _initializeUser();
  }

  void _listenToDiscountedPriceStream2(Stream<Map<String, double?>?>? stream) {
    if (stream != null) {
      stream.listen((newPrice) {
        setState(() {
          // Extract the value for the 'variety' key
          discountedPriceStream =
              newPrice?['variety'] as Stream<Map<String, double?>?>?;
        });
      });
    }
  }

  Future<void> _initializeUser() async {
    user ??= await User.guest();
  }

  @override
  void dispose() {
    // Clean up resources
    _debounce?.cancel();
    _autoScrollTimer?.cancel();
    _discountedPriceSubscription?.cancel();
    // No need to dispose ScrollController
    searchController.dispose(); // Dispose the search controller
    _predictedProductsController
        .close(); // Clean up the stream when the widget is disposed
    _scrollController
        .dispose(); // Don't forget to dispose of the controller when the widget is removed
    _hintTimer?.cancel();

    super.dispose();
  }

  Future<List<Product>> predictProducts(
    List<Product> recentlyBought,
    List<Product> products,
    List<Product> nearbyUsersBought,
    List<Product> seasonallyAvailable,
  ) async {
    // Gather complementary products based on nearby users' bought products
    List<Product> complementaryProducts = [];
    for (Product recent in recentlyBought) {
      complementaryProducts.addAll(
          products.where((product) => recent.isComplementaryTo(product)));
    }
    for (Product trending in nearbyUsersBought) {
      complementaryProducts.addAll(
          products.where((product) => trending.isComplementaryTo(product)));
    }
    for (Product seasonal in seasonallyAvailable) {
      complementaryProducts.addAll(
          products.where((product) => seasonal.isComplementaryTo(product)));
    }
    // Combine predictions, ensuring uniqueness using a Set
    List<Product> combinedPrediction = <Product>{
      ...seasonallyAvailable,
      ...complementaryProducts,
      ...nearbyUsersBought,
      ...recentlyBought,
    }.toList();

    // Fetch user-specific analytics data for each product in combinedPrediction
    List<Product> productsWithUserAnalytics = [];

    for (Product product in combinedPrediction) {
      final userAnalytics =
          await _userAnalyticsService.getUserProductAnalytics(user, product);
      product.userViews = userAnalytics['userViews'] ?? 0;
      product.userClicks = userAnalytics['userClicks'] ?? 0;
      product.userTimeSpent = userAnalytics['userFavorites'] ?? 0;
      productsWithUserAnalytics.add(product);
    }

    // Sort products based on user-specific analytics (e.g., prioritize by user clicks, then favorites, then views)
    productsWithUserAnalytics.sort((a, b) {
      if (b.userClicks != a.userClicks) {
        return b.userClicks.compareTo(a.userClicks);
      } else if (b.userTimeSpent != a.userTimeSpent) {
        return b.userTimeSpent!.compareTo(a.userTimeSpent as num);
      } else {
        return b.userViews!.compareTo(a.userViews as num);
      }
    });

    // Return only the top 10 products based on user activity
    return productsWithUserAnalytics.take(10).toList();
  }

  Widget buildLists(BuildContext context) {
      Map<String, List<Product>> categoryProducts = groupBy(products, (Product p) => p.category!);  

    return selectedCategory == null
        ? _buildCategorySelector(categoryProducts!)
        : _buildProductGrid(selectedCategory, categoryProducts!);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning ${user!.name!}';
    } else if (hour < 17) {
      return 'Good afternoon ${user!.name!}';
    } else {
      return 'Good evening ${user!.name!}';
    }
  }

// Add this helper method
  void _updateAppBarHeight() {
    final hasSuggestions = searchController.text.isNotEmpty;
    final newHeight = hasSuggestions ? 180.0 : 100.0;

    if (newHeight != _appBarBottomHeight) {
      setState(() => _appBarBottomHeight = newHeight);

      // Animate hint scroll only when height increases
      if (hasSuggestions) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _hintScrollController.animateTo(
            _hintScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  //Future<void> _fetchProductAnalytics() async {
  //final analyticsService = AnalyticsService();
  //final analytics = await analyticsService.getProductAnalytics(product!);

  //setState(() {
  // Assuming 'product' is a local variable, so this part will need to be adapted
  // For example: Use a state management solution to fetch and store the product
  //});
  //}

  void _logProductView(Product? product) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'view',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user!.id,
      'timestamp': DateTime.now(),
    });
  }

  void _logTimeSpent(Product? product, dynamic viewStartTime) {
    final viewEndTime = DateTime.now();
    final timeSpent = viewEndTime.difference(viewStartTime!).inSeconds;

    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'time_spent',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user!.id,
      'timeSpent': timeSpent,
      'timestamp': DateTime.now(),
    });
  }

  void _logClick(Product? product) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'click',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user!.id,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _initializeOffers() async {
    try {
      // Moved fetchOffers to its own method
      offers = await _offerProvider.fetchOffers();
    } catch (e) {
      print('Error initializing offers: $e');
    }
  }

  Future<void> _initializeProducts() async {
    try {
      var futureList = [
        _productProvider.fetchProducts(),
        _productProvider.fetchNearbyUsersBought(),
        _productProvider.fetchSeasonallyAvailable(),
        _userProvider.fetchFavorites(),
        _userProvider.fetchRecentlyBought(),
        _productProvider.fetchProductsByConsumptionTime(),
        _productProvider.fetchProductsByWeather(),
      ];

      // Await all futures and ensure type safety for results
      List<List<Product>> results =
          await Future.wait(futureList.map((future) => future));

      // Storing the results in class properties with proper casting
      products = results[0];
      nearbyUsersBought = results[1];
      seasonallyAvailable = results[2];
      favorites = results[3];
      recentlyBought = results[4];
      List<Product> consumptionTimeProducts = results[5];
      List<Product> weatherProducts = results[6];
      // Now you can use timeOfDayProducts and weatherProducts in your predictions or elsewhere
      // For example, you might want to add them to your prediction algorithm:
      List<Product> predictedProducts = await predictProducts(
        recentlyBought,
        products,
        nearbyUsersBought,
        [
          ...seasonallyAvailable,
          ...consumptionTimeProducts,
          ...weatherProducts
        ], // Combine seasonal, time, and weather products
      );
      // Add the new predicted products to the stream
      _predictedProductsController.add(predictedProducts);
      // Update UI after fetching data
      setState(() {});
    } catch (e, stackTrace) {
      print("Error initializing products, falling back to utils.dart: $e");
      print("Stack trace: $stackTrace");
      await _fetchFallbackProducts();
    }
  }

  Future<List<Product>> _fetchFallbackProducts() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      if (itemList != null && itemList.isNotEmpty) {
        final validProducts = itemList.whereType<Product>().toList();

        // Instead of setState, just return the products
        return validProducts;
      } else {
        debugPrint("itemList is empty or null in fallback");
        return []; // Return an empty list instead of null
      }
    } catch (e, stackTrace) {
      debugPrint("Error fetching fallback products: $e");
      debugPrint("StackTrace: $stackTrace");
      return []; // Return empty list on error
    }
  }

  void _filterProducts() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      String query = searchController.text.toLowerCase();

      if (query.isNotEmpty) {
        setState(() {
          // Create FuzzyOptions for the correct type (Product, Offer, and Category)
          final fuzzyOptionsForProducts =
              FuzzyOptions<Product>(shouldSort: true);
          final fuzzyOptionsForOffers = FuzzyOptions<Offer>(shouldSort: true);
          final fuzzyOptionsForCategories =
              FuzzyOptions<String>(shouldSort: true);

          // Create Fuzzy objects for products, offers, and categories
          final fuzzyProducts = Fuzzy<Product>(
            products,
            options: FuzzyOptions(
              keys: [
                WeightedKey(
                  name: 'name',
                  weight: 0.7,
                  getter: (p) => p.name,
                ),
                WeightedKey(
                  name: 'varieties',
                  weight: 0.3,
                  getter: (p) =>
                      p.varieties?.map((v) => v.name).join(' ') ?? '',
                ),
              ],
            ),
          );
          final fuzzyOffers =
              Fuzzy<Offer>(offers, options: fuzzyOptionsForOffers);
          final fuzzyCategories =
              Fuzzy<String>(categories, options: fuzzyOptionsForCategories);

          // Use fuzzy matching to filter products across different categories, including varieties
          List<Product> nearbyResults =
              _searchProductsAndVarieties(fuzzyProducts, query);
          List<Product> seasonalResults = _searchProductsAndVarieties(
              Fuzzy<Product>(seasonallyAvailable,
                  options: fuzzyOptionsForProducts),
              query);
          List<Product> favoriteResults = _searchProductsAndVarieties(
              Fuzzy<Product>(favorites, options: fuzzyOptionsForProducts),
              query);
          List<Product> recentlyBoughtResults = _searchProductsAndVarieties(
              Fuzzy<Product>(recentlyBought, options: fuzzyOptionsForProducts),
              query);

          // Filter products using similarity check, including varieties
          nearbyResults.addAll(nearbyUsersBought
              .where((product) =>
                  product.name.similarityTo(query) > 0.5 ||
                  product.varieties!
                      .any((variety) => variety.name.similarityTo(query) > 0.5))
              .toList());
          seasonalResults.addAll(seasonallyAvailable
              .where((product) =>
                  product.name.similarityTo(query) > 0.5 ||
                  product.varieties!
                      .any((variety) => variety.name.similarityTo(query) > 0.5))
              .toList());
          favoriteResults.addAll(favorites
              .where((product) =>
                  product.name.similarityTo(query) > 0.5 ||
                  product.varieties!
                      .any((variety) => variety.name.similarityTo(query) > 0.5))
              .toList());
          recentlyBoughtResults.addAll(recentlyBought
              .where((product) =>
                  product.name.similarityTo(query) > 0.5 ||
                  product.varieties!
                      .any((variety) => variety.name.similarityTo(query) > 0.5))
              .toList());

          // Rest of the method remains the same
          List<Product> complementaryResults = [];
          for (Product recent in recentlyBought) {
            complementaryResults.addAll(
                products.where((product) => recent.isComplementaryTo(product)));
          }
          for (Product trending in nearbyUsersBought) {
            complementaryResults.addAll(products
                .where((product) => trending.isComplementaryTo(product)));
          }
          complementaryResults.addAll(fuzzyProducts
              .search(query)
              .map((result) => result.item)
              .toList());

          // Combine all product results
          List<Product> combinedProductResults = [
            ...nearbyResults,
            ...seasonalResults,
            ...favoriteResults,
            ...recentlyBoughtResults,
            ...complementaryResults,
          ];

          // Use fuzzy matching to filter offers based on offer title
          List<Offer> offerResults =
              fuzzyOffers.search(query).map((result) => result.item).toList();

          // Extract products based on offer IDs
          List<Product> productsFromOffers = offerResults.expand((offer) {
            return products
                .where((product) => product.id == offer.productId)
                .toList();
          }).toList();

          // Use fuzzy matching to filter categories based on category name
          List<String> categoryResults = fuzzyCategories
              .search(query)
              .map((result) => result.item)
              .toList();

          // Map categories from product.categories for filtering
          List<Product> productsFromCategories =
              categoryResults.expand((category) {
            return products
                .where((product) => product.category == category)
                .toList();
          }).toList();

          // Merge filtered products, extracted products from offers, and categories into a single list
          filteredProducts = [
            ...combinedProductResults,
            ...productsFromOffers,
            ...productsFromCategories,
          ];

          // Update searchSuggestions with products, offer titles, and category names
          searchSuggestions = [
            ...combinedProductResults.map((product) => product.name),
            ...combinedProductResults
                .expand((p) => p.varieties!.map((v) => v.name!)),
            ...offerResults.map((offer) => offer.title!),
            ...categoryResults.map((category) => product!.category!),
          ].toSet().toList();

          if (!_hasInitialSuggestions) {
            _hasInitialSuggestions = true;
          }
        });
      } else {
        setState(() {
          searchSuggestions = [];
          filteredProducts = []; // Clear filtered products if query is empty
        });
      }
    });
  }

  // Helper method to search in both product names and varieties
  List<Product> _searchProductsAndVarieties(
      Fuzzy<Product> fuzzyProducts, String query) {
    Set<Product> matchedProducts = {};

    for (var result in fuzzyProducts.search(query)) {
      matchedProducts.add(result.item);
    }

    for (var product in fuzzyProducts.list) {
      if (product.varieties!.any((variety) => Fuzzy<Variety>([variety],
              options: FuzzyOptions<Variety>(shouldSort: true))
          .search(query)
          .isNotEmpty)) {
        matchedProducts.add(product);
      }
    }

    return matchedProducts.toList();
  }

  List<String> _getSearchSuggestions(BuildContext context) {
    const int maxSuggestions = 10;

    // If searchSuggestions is populated, return it directly
    if (searchSuggestions.isNotEmpty) {
      return searchSuggestions.take(maxSuggestions).toList();
    }

    Set<String> suggestions = {}; // Using a Set to remove duplicates

    // Check for previously searched products and add them
    suggestions.addAll(previouslySearchedProducts);

    // Filter orders based on the search query
    if (offers.isNotEmpty) {
      suggestions.addAll(offers.map((offer) =>
          offer.title!)); // Assuming `order.title` is the field to filter
    }

    // Only filter the other lists if searchSuggestions is empty
    if (seasonallyAvailable.isNotEmpty) {
      suggestions.addAll(seasonallyAvailable.map((product) => product.name));
    }
    if (nearbyUsersBought.isNotEmpty) {
      suggestions.addAll(nearbyUsersBought.map((product) => product.name));
    }
    if (recentlyBought.isNotEmpty) {
      suggestions.addAll(recentlyBought.map((product) => product.name));
    }
    if (products.isNotEmpty) {
      suggestions.addAll(products.map((product) => product.name));
    }

    // Cache the search query if not already present
    String query = searchController.text.toLowerCase();
    if (query.isNotEmpty && !previouslySearchedProducts.contains(query)) {
      previouslySearchedProducts.add(query);
    }

    // Return the unique suggestions, limited to maxSuggestions
    return suggestions.take(maxSuggestions).toList();
  }

  void _startHintAnimation() {
    _hintTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (searchController.text.isNotEmpty) return;

      final suggestions = _getSearchSuggestions(context);
      if (suggestions.isEmpty) return;

      setState(() {
        _currentHintIndex = (_currentHintIndex + 1) % suggestions.length;
      });
    });
  }

  String _getHintText() {
    final suggestions = _getSearchSuggestions(context);
    if (suggestions.isNotEmpty) {
      return suggestions[_currentHintIndex % suggestions.length];
    }
    return 'Search products...';
  }

  void _addToPreviouslySearched(String search) {
    if (!previouslySearchedProducts.contains(search)) {
      setState(() {
        previouslySearchedProducts.remove(search);
        previouslySearchedProducts.insert(0, search);
        if (previouslySearchedProducts.length > 5) {
          previouslySearchedProducts.removeLast();
        }
      });
    }
  }

  void _loadNotifications() async {
    // Assuming the notification model has an 'isRead' field
    List<NotificationModel> notifications =
        (await _notificationService.getNotifications())
            .cast<NotificationModel>();
    setState(() {
      notifications = notifications;
      _unreadNotificationsCount = notifications.where((n) => !n.isRead!).length;
    });
  }

  void _redirectToLogin() {
    // Redirect to a login screen if the user is not logged in
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  List<Product> _applyFiltersAndSort(List<Product>? products) {
    List<Product>? filteredProducts2 = products!.where((Product? product) {
      // Filter by price
      if (product!.basePrice == null ||
          product.basePrice! < minPrice! ||
          product.basePrice! > maxPrice!) return false;
      // Filter by subcategory
      if (selectedSubcategories.isNotEmpty &&
          !product.subcategories!
              .any((subcat) => selectedSubcategories.contains(subcat))) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    switch (sortBy) {
      case 'priceLow':
        filteredProducts.sort((a, b) => a.basePrice!.compareTo(b.basePrice!));
        break;
      case 'priceHigh':
        filteredProducts.sort((a, b) => b.basePrice!.compareTo(a.basePrice!));
        break;
      // Add more sorting options here if needed
      default:
        // No sorting applied
        break;
    }

    return filteredProducts2;
  }

  // Widget to display categories as selectable options
  Widget _buildCategorySelector(Map<String, List<Product>>? categoryProducts) {
    Map<String, List<Product>> categoryProducts = groupBy(products, (Product p) => p.category!);  

    if (categoryProducts == null) {
      return const Text("Loading or no products available");
    }

    List<String> categories = categoryProducts.keys.toList();

    return categories.isEmpty
        ? _buildEmptyState()
        : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 3,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              String category = categories[index];
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = category),
                child: Card(
                  elevation: 4,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  Future<void> fetchHealthBenefits(Product? product) async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse(apiUrl!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content":
                "List the health benefits of a product named ${product!.name}."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _healthBenefits = data['choices'][0]['message']['content'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _healthBenefits = "Failed to fetch health benefits. Try again!";
        _isLoading = false;
      });
    }
  }

  Future<void> fetchJoke(Product? product) async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse(apiUrl!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content":
                "You are copywriter in Kenya. Tell me a short, funny joke about a product named ${product!.name}."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _joke = data['choices'][0]['message']['content'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _joke = "Failed to fetch a joke. Try again!";
        _isLoading = false;
      });
    }
  }

  Future<void> fetchProductJourney(Product? product) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isLoading = true;
      });
    });

    final response = await http.post(
      Uri.parse(apiUrl!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content":
                "You are copywriter in Kenya. Write a short journey description for a product named ${product!.name}."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _dynamicJourney = data['choices'][0]['message']['content'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _dynamicJourney = "Failed to fetch product journey. Try again!";
        _isLoading = false;
      });
    }
  }

  Widget _buildJokeCard() {
    final randomProduct = getRandomProduct(); // Get a random product

    // Fetch the joke for the selected product
    fetchJoke(randomProduct);

    return Card(
      elevation: 5,
      child: Stack(
        children: [
          // Background image
          Image.network(
            randomProduct.pictureUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/basket.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Overlay for better readability
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _joke ?? "Loading a joke...",
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchReviewsForAnyProduct(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 5,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data ??
            [
              {
                'text': "No reviews available for any product.",
                'imageUrl': 'assets/images/basket.png'
              }
            ];
        final product = snapshot.data?.isNotEmpty == true
            ? Product(
                id: '0',
                name: 'No Products',
                pictureUrl: 'assets/images/basket.png',
                basePrice: null,
                description: '',
                category: '',
                categoryImageUrl: '',
                units: '',
                discountedPrice: null)
            : null;

        return Card(
          elevation: 5,
          child: Stack(
            children: [
              // Background image
              if (product != null)
                Image.network(
                  product.pictureUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/basket.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              // Overlay for better readability
              Container(
                color: Colors.black.withOpacity(0.5),
              ),
              // Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "User Reviews",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            return Text(
                              reviews[index]['text'],
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchReviewsForAnyProduct() async {
    try {
      // Start with the first product, then loop through until we find reviews or exhaust all products
      int productIndex = 0;
      List<Map<String, dynamic>> reviews = [];

      while (productIndex < predictedProducts.length && reviews.isEmpty) {
        Product product = predictedProducts[productIndex];
        reviews = await fetchReviewsForProduct(product.id ?? '');
        if (reviews.isNotEmpty) {
          // Add product information to each review if it's not already there
          return reviews.map((review) {
            review['productId'] = product.id;
            review['productName'] = product.name;
            review['imageUrl'] =
                product.pictureUrl; // Use product image for background
            return review;
          }).toList();
        }
        productIndex++;
      }

      // If no product has reviews
      return []; // Or return a default message as done in the builder
    } catch (e) {
      print("Error fetching reviews: $e");
      return [
        {
          'text': "Failed to fetch reviews. Try again!",
          'imageUrl': 'assets/images/basket.png'
        }
      ];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReviewsForProduct(
      String productId) async {
    try {
      final QuerySnapshot reviewSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .get();

      return reviewSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'text': data['text'] as String,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

// Add this method to get a random product
  Product getRandomProduct() {
    if (products.isEmpty) {
      return Product(
          id: '0',
          name: 'No Products',
          pictureUrl: 'assets/images/basket.png',
          basePrice: null,
          description: '',
          category: '',
          categoryImageUrl: '',
          units: '',
          discountedPrice: null);
    }
    final random = Random();
    return products[random.nextInt(products.length)];
  }

  Widget _buildJourneyCard() {
    final randomProduct = getRandomProduct(); // Get a random product

    if (_selectedJourneyProduct?.id != randomProduct.id) {
      _selectedJourneyProduct = randomProduct;
      fetchProductJourney(randomProduct);
    }

    return Card(
      elevation: 5,
      child: Stack(
        children: [
          // Background image
          Image.network(
            randomProduct.pictureUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/basket.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Overlay for better readability
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _dynamicJourney ?? "Loading product journey...",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictedProducts() {
    return FutureBuilder<List<Product>>(
      future: predictProducts(
        recentlyBought,
        products,
        nearbyUsersBought,
        seasonallyAvailable,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading recommendations: ${snapshot.error}'),
          );
        }

        final predictedProducts = snapshot.data ?? [];
        final carouselItems = <Widget>[];

        // Add predicted product cards
        if (predictedProducts.isNotEmpty) {
          carouselItems.addAll(
            predictedProducts.map(
              (product) => _buildProductCard(
                product,
                isGrid: false,
              ),
            ),
          );
        }

        // Add informational cards
        carouselItems.addAll([
          _buildJourneyCard(),
          _buildReviewCard(),
          if (_joke != null) _buildJokeCard(),
          _buildHealthBenefitsCard(),
        ]);

        return Column(
          children: [
            cs.CarouselSlider(
              items: carouselItems.map((item) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: item,
                    );
                  },
                );
              }).toList(),
              options: cs.CarouselOptions(
                // Vertical scrolling
                scrollDirection: Axis.vertical,
                height: 300, // This will now represent the height of each item
                autoPlay: carouselItems.length > 1,
                autoPlayInterval: const Duration(seconds: 5),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
                enlargeCenterPage: true,
                onPageChanged: (index, reason) {
                  setState(() => _currentIndex = index);
                },
                // Adjust viewportFraction for vertical layout
                viewportFraction: 0.8,
                aspectRatio:
                    16 / 9, // Depending on your design, adjust this ratio
              ),
            ),
            const SizedBox(height: 20),
            _buildPageIndicators(carouselItems.length),
          ],
        );
      },
    );
  }

  Widget _buildPageIndicators(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentIndex == index
                ? Colors.blue
                : Colors.grey.withOpacity(0.5),
          ),
        );
      }),
    );
  }

  Widget _buildHealthBenefitsCard() {
    final randomProduct = getRandomProduct(); // Get a random product

    if (_selectedHealthBenefitsProduct?.id != randomProduct.id) {
      _selectedHealthBenefitsProduct = randomProduct;
      fetchHealthBenefits(randomProduct);
    }

    return Card(
      elevation: 5,
      child: Stack(
        children: [
          // Background image
          Image.network(
            randomProduct.pictureUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/basket.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Overlay for better readability
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _healthBenefits ?? "Loading health benefits...",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _requestStockNotification(String productId) async {
    NotificationService notificationService = NotificationService();
    final token = await FirebaseMessaging.instance.getToken();

    // Example data to be sent with the notification
    Map<String, dynamic> notificationData = {
      'productId': productId,
      'action': 'stock_update',
    };

    // Call NotificationService to send a notification
    await notificationService.sendNotification(
      to: token!, // Replace with actual token if using FCM
      title: 'Stock Alert!',
      body: 'Your product with ID $productId is back in stock!',
      data: notificationData,
    );

    print('Requesting notification for product: $productId');
  }

  Widget _buildProductGrid(
      String? currentCategory, Map<String, List<Product>> categoryProducts) {
      Map<String, List<Product>> categoryProducts = groupBy(products, (Product p) => p.category!);  

    List<Product> productsToShow =
        currentCategory != null ? categoryProducts[currentCategory] ?? [] : [];

    // Apply filters and sort
    productsToShow = _applyFiltersAndSort(productsToShow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentCategory != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  currentCategory,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => selectedCategory = null),
                ),
                const Spacer(),
                Column(
                  children: [
                    if (productsToShow.isNotEmpty)
                      _buildFilterAndSortControls(),
                  ],
                )
              ],
            ),
          ),
        if (productsToShow.isEmpty)
          _buildEmptyState()
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
                childAspectRatio: 0.75,
              ),
              itemCount: productsToShow.length,
              itemBuilder: (context, index) =>
                  _buildProductCard(productsToShow[index], isGrid: true),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterAndSortControls() {
    return Column(
      children: [
        // Price Range Slider
        RangeSlider(
          values: RangeValues(minPrice!, maxPrice!),
          min: 0.0,
          max: 1000.0, // Adjust max price based on your product range
          onChanged: (RangeValues values) {
            setState(() {
              minPrice = values.start;
              maxPrice = values.end;
            });
          },
        ),
        Text(
            'Price: \$ ${minPrice!.toStringAsFixed(2)} - \$ ${maxPrice!.toStringAsFixed(2)}'),

        // Subcategory Filter (assuming subcategories are predefined)
        Wrap(
          children: List.generate(
            subcategories.length,
            (index) => ChoiceChip(
              label: Text(subcategories[index]),
              selected: selectedSubcategories.contains(subcategories[index]),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedSubcategories.add(subcategories[index]);
                  } else {
                    selectedSubcategories.remove(subcategories[index]);
                  }
                });
              },
            ),
          ),
        ),

        // Sorting Dropdown
        DropdownButton<String>(
          value: sortBy,
          onChanged: (String? newValue) {
            setState(() {
              sortBy = newValue!;
            });
          },
          items: <String>['default', 'priceLow', 'priceHigh']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'default'
                  ? 'Default'
                  : value == 'priceLow'
                      ? 'Price: Low to High'
                      : 'Price: High to Low'),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHorizontalProductList(List<Product> products) {
    return products.isEmpty
        ? _buildEmptyState()
        : SizedBox(
            height: 250.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _buildProductCard(products[index], isGrid: false),
            ),
          );
  }

  // Existing empty state widget
  Widget _buildEmptyState() {
    final Product product;

    return const Center(
      child: Text(
        "No products available",
        style: TextStyle(color: Colors.grey, fontSize: 18),
      ),
    );
  }

  Widget _buildProductCard(Product? product, {required bool isGrid}) {
    final productImageUrl = product!.pictureUrl!.isNotEmpty
        ? product.pictureUrl
        : 'assets/images/basket.png';
    final productName = product.name.isNotEmpty ? product.name : 'Mystery Item';
    final productCategory = product.category;
    final productReviewCount = product.reviewCount;
    final productUnits = product.units;
    final productPrice = product.discountedPriceStream2 != null
        ? '\$${product.discountedPriceStream2}'
        : 'Discover';
    double? originalPrice =
        product.basePrice; // Assuming you have an original price

    String? couponDiscount;
    // Calculate discount percentage if both prices are available
    String? discountPercentage;
    if (originalPrice != null) {
      double? discountedPrice;

      // Check variety's discounted price first
      if (product.variety != null &&
          product.variety!.discountedPriceStream != null) {
        discountedPrice = product.variety!.discountedPriceStream as double?;
      } else if (product.discountedPriceStream2 != null) {
        discountedPrice = product.discountedPriceStream2 as double?;
      }

      if (discountedPrice != null && originalPrice > discountedPrice) {
        double percentage =
            ((originalPrice - discountedPrice) / originalPrice) * 100;
        discountPercentage = '-${percentage.toStringAsFixed(0)}%';
      }
    }

    // Check if the product is in stock
    bool inStock = _productProvider.isInStock(product);
    const int highlyRatedThreshold = 100;
    // Create a dynamic list of icons
    List<IconDetail> dynamicIconsList = [
      IconDetail(
          image: 'assets/icons/LikeOutline.svg', head: 'Quality\nAssurance'),
      IconDetail(
          image: 'assets/icons/SpoonOutline.svg', head: 'Best In\nTaste'),
    ];

    // Add "Highly Rated" icon if the review count exceeds the threshold
    if (product != null && product.reviewCount! > highlyRatedThreshold) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/StartOutline.svg', head: 'Highly\nRated'),
      );
    }

// Conditionally add icons based on new fields
    if (product.isFresh ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.water_drop, color: Colors.green, size: 28),
          head: 'Freshness\nGuaranteed',
        ),
      );
    }

    if (product.isLocallySourced ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.location_on, color: Colors.blue, size: 28),
          head: 'Locally\nSourced',
        ),
      );
    }

    if (product.isOrganic ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.eco, color: Colors.lightGreen, size: 28),
          head: 'Organic\nChoice',
        ),
      );
    }

    if (product.hasHealthBenefits ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon:
              const Icon(Icons.health_and_safety, color: Colors.red, size: 28),
          head: 'Health\nBenefits',
        ),
      );
    }

    if (product.hasDiscounts ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.percent, color: Colors.orange, size: 28),
          head: 'Great\nDiscounts',
        ),
      );
    }

    if (product.isSeasonal ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon:
              const Icon(Icons.calendar_today, color: Colors.purple, size: 28),
          head: 'Seasonal\nFavorites',
        ),
      );
    }

    if (product.isEcoFriendly ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.recycling, color: Colors.teal, size: 28),
          head: 'Eco-Friendly',
        ),
      );
    }

    if (product.isSuperfood ?? false) {
      dynamicIconsList.add(
        IconDetail(
          icon: const Icon(Icons.star, color: Colors.amber, size: 28),
          head: 'Superfoods',
          image: '',
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductScreen(productId: product.id ?? ''),
          ),
        );
        _logProductView;
        _logTimeSpent;
        _logClick(product);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isFlipped = true),
        onExit: (_) => setState(() => _isFlipped = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: _isFlipped!
              ? (Matrix4.identity()..rotateY(3.14))
              : Matrix4.identity(),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: _isFlipped!
              ? _buildBackSide(product, dynamicIconsList)
              : _buildFrontSide(
                  productImageUrl!,
                  productName,
                  productPrice,
                  discountPercentage,
                  originalPrice,
                  inStock,
                  couponDiscount,
                  productCategory,
                  productReviewCount,
                  productUnits,
                ),
        ),
      ),
    );
  }

// Front side of the product card with parallax scrolling, selectable varieties, cart button, and quantity selector
  Widget _buildFrontSide(
      String productImageUrl,
      String productName,
      String productPrice,
      String? discountPercentage,
      double? originalPrice,
      bool inStock,
      String? couponDiscount,
      String? productCategory,
      int? productReviewCount,
      String? productUnits,
      [List<Variety>? varieties]) {
    Variety? selectedVariety =
        varieties?.isNotEmpty ?? false ? varieties?.first : null;
    Function(Variety)? onVarietySelected; // New callback for selecting variety
    Function(int)? onQuantityChanged; // New callback for changing quantity
    int? initialQuantity = 1; // Initial quantity for the selector

    onAddToCart() {
      // Assuming you have a CartProvider or similar for managing cart
      var notes;
      Provider.of<CartProvider>(context, listen: false).addItem(
          product!, user!, selectedVariety, initialQuantity, notes ?? '');
      // Optionally show a snackbar or update UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product!.name} added to cart')),
      );
    } // Change here from Function? to VoidCallback?

    num averageRating = 0;
    if (product!.reviews!.isNotEmpty) {
      averageRating = product!.reviews!
              .map((review) => review.rating)
              .reduce((a, b) => a + b) /
          product!.reviews!.length;
    }

    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final offset = _scrollController.offset;
        final height = MediaQuery.of(context).size.height;
        final position = (offset / height) * 2;
        final scale = max(1.0, 1.0 + position / 3);

        return Transform.translate(
          offset: Offset(0, position * 30),
          child: Transform.scale(
            scale: scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          child: Image.network(
                            selectedVariety != null &&
                                    selectedVariety?.imageUrl != null
                                ? selectedVariety!
                                    .imageUrl! // Removed incorrect '\$' and unnecessary string interpolation
                                : productImageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : _buildLoadingShimmer(),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(8.0),
                        height: 120,
                        width: MediaQuery.of(context).size.width / 2.5,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              productCategory!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 5,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              productName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: List.generate(
                                5,
                                (starIndex) => Icon(
                                  Icons.star,

                                  // Then use averageRating for your condition:
                                  color: starIndex < averageRating
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Text(
                              " (${productReviewCount!} reviews)",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (discountPercentage != null)
                                  Text(
                                    '\$$originalPrice',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                Text(
                                  selectedVariety != null &&
                                          selectedVariety?.price != null
                                      ? '\$${selectedVariety!.price}'
                                      : productPrice,
                                  style: TextStyle(
                                      color: Colors.orange.withOpacity(0.75),
                                      fontSize: 16),
                                ),
                                Text(
                                  "PER ${productUnits ?? ''}",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 16),
                                )
                              ],
                            ),
                            // Quantity selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: initialQuantity > 1
                                      ? () => onQuantityChanged!(
                                          initialQuantity - 1)
                                      : null,
                                ),
                                Text(initialQuantity.toString()),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () =>
                                      onQuantityChanged!(initialQuantity + 1),
                                ),
                              ],
                            ),
                            // Add to cart button
                            ElevatedButton(
                              onPressed: inStock ? onAddToCart : null,
                              child: Text(
                                  inStock ? 'Add to Cart' : 'Out of Stock'),
                            ),
                          ],
                        ),
                      ),
                      // Varieties list with images below product info
                      if (varieties!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListView(
                            scrollDirection: Axis
                                .horizontal, // Scroll horizontally instead of vertically
                            children: varieties.map((variety) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedVariety = variety;
                                    onVarietySelected!(variety);
                                  });
                                },
                                child: Row(
                                  children: [
                                    if (variety.imageUrl != null)
                                      Container(
                                        width: 25,
                                        height: 25,
                                        margin:
                                            const EdgeInsets.only(right: 8.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.network(
                                            variety.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(Icons.error,
                                                        size: 24),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(variety.name!),
                                        subtitle: Text.rich(
                                          TextSpan(
                                            children: [
                                              if (selectedVariety!
                                                          .discountedPriceStream !=
                                                      null &&
                                                  selectedVariety!
                                                          .discountedPriceStream! !=
                                                      0.0)
                                                TextSpan(
                                                  text:
                                                      ' \$${selectedVariety!.price?.toStringAsFixed(2) ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              TextSpan(
                                                text: selectedVariety!
                                                                .discountedPriceStream !=
                                                            null &&
                                                        selectedVariety!
                                                                .discountedPriceStream! !=
                                                            0.0
                                                    ? ' \$${selectedVariety!.discountedPriceStream?.toStringAsFixed(2) ?? 'N/A'}'
                                                    : selectedVariety!.price !=
                                                            null
                                                        ? ' \$${selectedVariety!.price?.toStringAsFixed(2)}'
                                                        : ' Price not available',
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing: selectedVariety == variety
                                            ? const Icon(Icons.check,
                                                color: Colors.green)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                  // Rest of the Stack elements (discounts, out of stock, coupon)
                  if (discountPercentage != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          discountPercentage,
                          style: const TextStyle(
                              color: Color.fromARGB(255, 180, 177, 177),
                              fontSize: 12),
                        ),
                      ),
                    ),
                  if (!inStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  // Coupon badge overlay
                  if (couponDiscount != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Coupon: $couponDiscount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  // Offer title overlay
                  if (offer != null && product!.id! == offer!.productId!)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          offer!.title!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),

                  // Out of stock options
                  if (!inStock)
                    Positioned(
                      bottom: 40, // Adjust position as needed
                      left: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Request notification when back in stock
                          ElevatedButton(
                            onPressed: () {
                              _requestStockNotification(product!.id!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: const Text(
                              'Notify Me When Back in Stock',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Recommend genomic alternatives
                          if (_genomicAlternatives.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recommended Alternatives:',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ..._genomicAlternatives.map((alternative) {
                                  return ListTile(
                                    leading: Image.network(
                                      alternative.pictureUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                    title: Text(
                                      alternative.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    subtitle: Text(
                                      'Price: ${alternative.basePrice!}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    onTap: () {
                                      if (alternative.id != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProductScreen(
                                                productId: alternative.id!),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Back side of the product card (e.g., dynamic icons list)
  Widget _buildBackSide(Product product, List<IconDetail> dynamicIconsList) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.blueAccent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Product Highlights',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: dynamicIconsList
                .map((iconDetail) => Column(
                      children: [
                        SvgPicture.asset(iconDetail.image!,
                            height: 30, width: 30),
                        const SizedBox(height: 4),
                        Text(
                          iconDetail.head,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductScreen(productId: product.id ?? ''),
                ),
              );
              _logProductView;
              _logTimeSpent;
              _logClick(
                product,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'View Details',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Loading shimmer effect
  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 15.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ));
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    if (_userProvider.user!.isAdmin! ||
        _userProvider.user!.isRider! ||
        _userProvider.user!.isAttendant!) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return GestureDetector(
            onTapDown: (_) =>
                setState(() => _isPressed = true), // Button press effect
            onTapUp: (_) =>
                setState(() => _isPressed = false), // Reset when released
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              // Button action logic here
              if (_userProvider.user!.isAdmin! &&
                  !_userProvider.user!.isRider!) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen()));
              } else if (_userProvider.user!.isRider!) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PendingDeliveriesScreen()));
              } else if (_userProvider.user!.isAttendant!) {
                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_box),
                          title: const Text('Add Products'),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const AdminAddProductScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.local_offer),
                          title: const Text('Create Offers'),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const AdminOffersScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.local_offer),
                          title: const Text('Pending Deliveries'),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    const PendingDeliveriesScreen()));
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()
                ..scale(_isPressed
                    ? 0.9
                    : 1.0) // Ensure ternary condition works properly
                ..rotateZ(_isPressed
                    ? -0.02
                    : 0), // Add a slight rotation effect on press
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: _isPressed ? 5 : 15, // Less shadow when pressed
                    offset:
                        _isPressed ? const Offset(0, 2) : const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void _onNotificationPressed() {
    // Your logic for handling notifications, e.g., navigating to notifications screen
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const NotificationScreen()));
  }

  void _openWhatsApp() async {
    const String phoneNumber = '+254705635198';
    const String message = 'Hello! I have a query about your products.';
    final Uri uri = Uri.parse('https://wa.me/$phoneNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    User? user;
    final isHomeScreen = ModalRoute.of(context)?.settings.name ==
        '/home'; // Adjust the route name as needed

    Future<List<Product>> predictedProducts = predictProducts(
      recentlyBought,
      products,
      nearbyUsersBought,
      seasonallyAvailable,
    );

    // Group products by category
    Map<String, List<Product>>? categoryProducts = {};
    for (var product in products) {
      // Use all products, not filtered ones, for categories
      if (!categoryProducts.containsKey(product.category)) {
        categoryProducts[product.category!] = [];
      }
      categoryProducts[product.category]!.add(product);
    }

    return Scaffold(
      body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned:
                    true, // Ensures that the app bar remains visible as the user scrolls.
                leading: isHomeScreen
                    ? null // No back button if on the home screen.
                    : IconButton(
                        tooltip: 'Back', // Tooltip for back navigation.
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.of(context)
                              .pop(); // Navigate back to the previous screen.
                        },
                      ),
                title: Row(
                  children: [
                    GestureDetector(
                      onTapDown: (_) {
                        // Animation trigger when pressed.
                      },
                      onTapUp: (_) {
                        // Additional logic on release can be added here.
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.2), // Shadow color.
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0,
                                  4), // Shadow offset (horizontal, vertical).
                            ),
                          ],
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 0.1),
                          duration: const Duration(
                              milliseconds:
                                  500), // Duration for the bounce effect.
                          curve: Curves.elasticInOut, // Elastic effect curve.
                          builder: (context, tiltValue, child) {
                            return GlassmorphicContainer(
                              width: 100,
                              height: 100,
                              borderRadius: 20,
                              blur: 15,
                              alignment: Alignment.center,
                              border: 2,
                              linearGradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderGradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(
                                      3, 2, 0.001) // Perspective setting.
                                  ..rotateY(
                                      tiltValue) // Subtle rotation along Y-axis.
                                  ..rotateX(
                                      tiltValue), // Subtle rotation along X-axis.
                                alignment: FractionalOffset.center,
                                child: Lottie.network(
                                  'https://lottie.host/f0e504ff-1b4a-43d1-a08c-93fa0aa5e4ae/6xKWN4vKCF.json',
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(
                        width: 8), // Spacing between the logo and title.
                    const Text('SOKONI\'S!'),
                  ],
                ),
                actions: [
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Apply perspective effect.
                      ..rotateY(0.1), // Slight rotation along the Y-axis.
                    alignment: Alignment.center,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return IconButton(
                          tooltip: 'Profile', // Tooltip for the profile button.
                          icon: const Icon(Icons.person),
                          onPressed: () {
                            setState(() {
                              // Code to modify the background color, if necessary.
                            });
                            if (_userProvider.isLoggedIn) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen()),
                              );
                            } else {
                              _redirectToLogin();
                            }
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.blue;
                                }
                                return null; // Use the widget's default color otherwise.
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Maintain perspective.
                      ..rotateY(-0.1),
                    alignment: Alignment.center,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Perspective effect.
                            ..rotateX(-0.05),
                          child: IconButton(
                            tooltip:
                                'Notifications', // Tooltip for notifications.
                            icon: Stack(
                              children: [
                                const Icon(Icons.notifications),
                                if (_unreadNotificationsCount! > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 12,
                                        minHeight: 12,
                                      ),
                                      child: Text(
                                        '$_unreadNotificationsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () {
                              setState(() {
                                // Code to modify the background color, if necessary.
                              });
                              _onNotificationPressed();
                            },
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.pressed)) {
                                    return Colors.blue;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            iconSize: 30,
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    transform: Matrix4.identity()
                      ..setEntry(
                          3, 2, 0.001) // Apply perspective transformation.
                      ..rotateX(0.05),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return IconButton(
                          tooltip:
                              'Messages', // Tooltip for the messaging function.
                          icon: const Icon(Icons.message),
                          onPressed: () {
                            setState(() {
                              // Code to modify the background color, if required.
                            });
                            _openWhatsApp();
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.blue;
                                }
                                return null;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    transform: Matrix4.identity()
                      ..setEntry(
                          3, 2, 0.001) // Apply perspective transformation.
                      ..rotateX(0.05),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return IconButton(
                          tooltip: 'Offers', // Tooltip for the offers section.
                          icon: const Icon(Icons.local_offer),
                          onPressed: () {
                            setState(() {
                              // Modify the background color here, if needed.
                            });
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const OffersPage(),
                              ),
                            );
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.blue;
                                }
                                return null;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    transform: Matrix4.identity()
                      ..setEntry(
                          3, 2, 0.001) // Apply perspective transformation.
                      ..rotateX(0.05),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return IconButton(
                          tooltip: 'Cart', // Tooltip for the shopping cart.
                          icon: const Icon(Icons.shopping_cart),
                          onPressed: () {
                            setState(() {
                              // Code to modify the background color if required.
                            });
                            if (_userProvider.isLoggedIn) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const CartScreen()),
                              );
                            } else {
                              _redirectToLogin();
                            }
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.blue;
                                }
                                return null;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(_appBarBottomHeight),
                  child: Container(
                    height: _appBarBottomHeight,
                    padding: const EdgeInsets.all(8.0),
                    child: CustomScrollView(
                      controller: _hintScrollController,
                      slivers: [
                        // Main sliver containing the search bar
                        SliverToBoxAdapter(
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                    horizontal: 48.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  prefixIcon: searchController.text.isEmpty
                                      ? Icon(Icons.search, color: mainColor)
                                      : null,
                                  suffixIcon: searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear,
                                              color: mainColor),
                                          onPressed: () {
                                            setState(() {
                                              searchController.clear();
                                              _filterProducts();
                                              _updateAppBarHeight();
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _filterProducts();
                                    _updateAppBarHeight();
                                  });
                                  _searchDebouncer.run(() {
                                    if (value.isNotEmpty) {
                                      _addToPreviouslySearched(value);
                                    }
                                  });
                                },
                              ),
                              if (searchController.text.isEmpty)
                                IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 48.0),
                                    height: 48.0,
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      height: 20.0,
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        transitionBuilder: (child, animation) =>
                                            SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.0, 0.5),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                        child: Marquee(
                                          key: ValueKey(_currentHintIndex),
                                          text: _getHintText(),
                                          scrollAxis: Axis.vertical,
                                          blankSpace: 20.0,
                                          velocity: 30.0,
                                          pauseAfterRound:
                                              const Duration(seconds: 1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8.0),

                        // Conditional suggestions sliver
                        if (searchController.text.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 40.0,
                              child: ListView.builder(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    _getSearchSuggestions(context).length,
                                itemBuilder: (context, index) {
                                  final suggestion =
                                      _getSearchSuggestions(context)[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: ActionChip(
                                      label: Text(suggestion,
                                          style:
                                              const TextStyle(fontSize: 14.0)),
                                      onPressed: () {
                                        setState(() {
                                          searchController.text = suggestion;
                                          _filterProducts();
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        // Previously searched products sliver
                        if (previouslySearchedProducts.isNotEmpty &&
                            searchController.text.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8.0),
                                const Text(
                                  'Previously Searched Products:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.0),
                                ),
                                const SizedBox(height: 8.0),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: previouslySearchedProducts
                                        .map((product) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child: ActionChip(
                                          label: Text(product,
                                              style: const TextStyle(
                                                  fontSize: 14.0)),
                                          onPressed: () {
                                            setState(() {
                                              searchController.text = product;
                                              _filterProducts();
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16.0),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            ];
          },
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Stretch for full width
              children: [
                Column(
                  children: [
                    Text(_getGreeting(), style: const TextStyle(fontSize: 24)),
                  ],
                ),
                if (offers.isNotEmpty && searchController.text.isEmpty)
                  Column(
                    children: [
                      _buildSectionTitle('Special Offers'),
                      cs.CarouselSlider(
                        options: cs.CarouselOptions(
                          height: 250.0,
                          autoPlay: true,
                          viewportFraction:
                              0.8, // Smaller fraction for a more focused center item
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enableInfiniteScroll: true,
                          autoPlayAnimationDuration:
                              const Duration(milliseconds: 800),
                          enlargeCenterPage: true,
                          enlargeStrategy: cs.CenterPageEnlargeStrategy.scale,
                        ),
                        items: offers.map((offer) {
                          return Builder(
                            builder: (BuildContext context) {
                              return GestureDetector(
                                onTap: () {
                                  // Navigate to product screen
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProductScreen(
                                          productId: offer.productId!),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 5.0, vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          offer.imageUrl!,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            );
                                          },
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black54,
                                                ],
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  offer.title!,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${offer.price}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                // Check if the searchController.text is not empty and filteredProducts has items
                if (searchController.text.isNotEmpty) ...[
                  _buildSectionTitle('Search Results'),
                  filteredProducts.isNotEmpty
                      ? Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final product = filteredProducts[index];
                                    return _buildProductCard(products[index],
                                        isGrid: false);
                                  },
                                  childCount: filteredProducts.length,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "No products found",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                ],

                // Regular product display when there's no search query
                if (searchController.text.isEmpty) ...[
                  _buildSectionTitle('Just For You!'),
                  _buildPredictedProducts(), // Products grouped by category in a grid
                  _buildSectionTitle('Recently Bought'),
                  _buildHorizontalProductList(recentlyBought),
                  _buildSectionTitle('Favorites'),
                  _buildHorizontalProductList(favorites),

                  _buildSectionTitle('Products by Category'),
                  for (String category in categoryProducts.keys) ...[
                    _buildSectionTitle(category),
                    _buildCategorySelector(categoryProducts[category]!
                        as Map<String, List<Product>>),
                  ],
                ],
              ],
            ),
          )),
      // FloatingActionButton logic for Admin, Rider, or Attendant users
      floatingActionButton: _userProvider.user!.isAdmin! ||
              _userProvider.user!.isRider! ||
              _userProvider.user!.isAttendant!
          ? _buildFloatingActionButton(context)
          : null,
    );
  }
}

extension on Stream<Map<String, double?>?>? {
  toStringAsFixed(int i) {}
}

class IconDetail {
  IconDetail({this.image, required this.head, this.icon});

  final String head;
  final String? image;
  final Icon? icon;
}

class _Debouncer {
  final int milliseconds;
  VoidCallback? _action;
  Timer? _timer;

  _Debouncer({this.milliseconds = 500});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}


