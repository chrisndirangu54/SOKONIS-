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
import 'package:auto_size_text/auto_size_text.dart';
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
  // Define all possible tags here or load them dynamically
  final List<String> tags = [];
  bool? isSearching = false;
  List<Product> nearbyUsersBought = [];
  List<NotificationModel>? notifications = [];
  List<Offer> offers = [];
  List<Product> predictedProducts = [];
  List<String> previouslySearchedProducts =
      []; // Cache for previously searched products
  String? sortBy = 'default'; // default, priceLow, priceHigh, etc.
  List<String> selectedtags =
      []; // Assuming products can belong to multiple tags
  double? minPrice = 0.0;
  double? maxPrice = double.infinity;
  List<Product> products = [];
  List<Product> recentlyBought = [];
  TextEditingController searchController = TextEditingController();
  List<String> searchSuggestions = [];
  List<Product> seasonallyAvailable = [];
  String? selectedCategory;
  late List<String> selectedSubcategories = [];
  User? user;
  String? _healthBenefits;
  Product? _selectedHealthBenefitsProduct;
  Product? product;
  Timer? _autoScrollTimer;
  Timer? _debounce;
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
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  List<String> allTags = []; // Store all unique tags
  String? selectedTag; // Track the currently selected tag
  List<Product> tagFilteredProducts = []; // Products filtered by selected tag

  static var _searchDebouncer;
  
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
            discountedPrice = price;
          });
        },
      );

      // Check if product has varieties before iterating
      for (var variety in widget.product!.varieties) {
        if (variety.discountedPriceStream != null) {
          _listenToDiscountedPriceStream2(variety.discountedPriceStream!);
        }
      }
    } else {
      print("Product is null in HomeScreen initState");
    }

    _initializeUser();
    _initializeTags(); // Initialize tags
  }

  void _initializeTags() {
    // Extract unique tags from products
    setState(() {
      allTags = products
          .expand((product) => product.tags)
          .toSet()
          .toList()
        ..sort(); // Optional: sort alphabetically
    });
  }

  void _filterProductsByTag(String tag) {
    setState(() {
      selectedTag = tag;
      tagFilteredProducts = products.where((product) => product.tags.contains(tag)).toList();
    });
  }

  void _clearTagFilter() {
    setState(() {
      selectedTag = null;
      tagFilteredProducts = [];
    });
  }


  void _listenToDiscountedPriceStream2(Stream<Map<String, double?>?>? stream) {
    if (stream != null) {
      stream.listen((newPrice) {
        setState(() {
          // Extract the value for the 'variety' key
          discountedPrice =
              newPrice?['variety'];
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
          await _userAnalyticsService.getUserProductAnalytics(user!, product);
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


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning ${user!.name}';
    } else if (hour < 17) {
      return 'Good afternoon ${user!.name}';
    } else {
      return 'Good evening ${user!.name}';
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
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
      'timestamp': DateTime.now(),
    });
  }

  void _logTimeSpent(Product? product, dynamic viewStartTime) {
    final viewEndTime = DateTime.now();
    final timeSpent = viewEndTime.difference(viewStartTime!).inSeconds;

    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'time_spent',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
      'timeSpent': timeSpent,
      'timestamp': DateTime.now(),
    });
  }

  void _logClick(Product? product, String action) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'click',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
      'action': '',
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
    products = results[0].map((p) {
      p.categories = p.categories.map((c) {
        return Category(
          name: c.name,
          imageUrl: c.imageUrl.isNotEmpty ? c.imageUrl : 'https://via.placeholder.com/150', // Mock or fetch
          subcategories: c.subcategories.map((s) {
            return Subcategory(
              name: s.name,
              imageUrl: s.imageUrl.isNotEmpty ? s.imageUrl : 'https://via.placeholder.com/150', // Mock or fetch
            );
          }).toList(),
        );
      }).toList();
      return p;
    }).toList();
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
          ...weatherProducts,
          ...favorites,
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

      if (itemList.isNotEmpty) {
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
  String query = searchController.text.toLowerCase();

  if (query.isNotEmpty) {
    setState(() {
      // Extract unique tags, subcategories, and categories
      List<String> allTags = products.expand((p) => p.tags).toSet().toList();
      List<String> allSubcategories = products
          .expand((p) => p.categories)
          .expand((c) => c.subcategories.map((s) => s.name))
          .toSet()
          .toList();
      List<String> allCategories = products.expand((p) => p.categories.map((c) => c.name)).toSet().toList();

      // Define fuzzy search options
      final fuzzyOptions = FuzzyOptions<String>(shouldSort: true);

      // Create fuzzy search objects
      final fuzzyTags = Fuzzy<String>(allTags, options: fuzzyOptions);
      final fuzzySubcategories = Fuzzy<String>(allSubcategories, options: fuzzyOptions);
      final fuzzyCategories = Fuzzy<String>(allCategories, options: fuzzyOptions);

      // Perform fuzzy searches
      List<String> matchingTags = fuzzyTags.search(query).map((result) => result.item).toList();
      List<String> matchingSubcategories = fuzzySubcategories.search(query).map((result) => result.item).toList();
      List<String> categoryResults = fuzzyCategories.search(query).map((result) => result.item).toList();

      // Filter products by tags
      List<Product> productsFromTags = products.where((product) {
        return product.tags.any((tag) => matchingTags.contains(tag));
      }).toList();

      // Filter products by subcategories
      List<Product> productsFromSubcategories = products.where((product) {
        return product.categories.any((category) {
          return category.subcategories.any((subcategory) {
            return matchingSubcategories.contains(subcategory.name);
          });
        });
      }).toList();

      // Filter products by categories
      List<Product> productsFromCategories = products.where((product) {
        return product.categories.any((category) => categoryResults.contains(category.name));
      }).toList();

      // Add similarity check for product names and varieties
      List<Product> similarityResults = products.where((product) {
        bool nameMatch = product.name.similarityTo(query) > 0.5;
        bool varietyMatch = product.varieties.any((variety) => variety.name.similarityTo(query) > 0.5);
        return nameMatch || varietyMatch;
      }).toList();

      // Combine all filtered results, removing duplicates
      filteredProducts = [
        ...productsFromCategories,
        ...productsFromSubcategories,
        ...productsFromTags,
        ...similarityResults,
      ].toSet().toList();

      // Update search suggestions
      searchSuggestions = [
        ...matchingTags,
        ...matchingSubcategories,
        ...categoryResults,
        ...similarityResults.map((p) => p.name),
        ...similarityResults.expand((p) => p.varieties.map((v) => v.name)),
      ].toSet().toList();
    });
  } else {
    setState(() {
      filteredProducts = [];
      searchSuggestions = [];
    });
  }
}

  // Helper method to search in both product names and varieties

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
          offer.title)); // Assuming `order.title` is the field to filter
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
      _unreadNotificationsCount = notifications.where((n) => !n.isRead).length;
    });
  }

  void _redirectToLogin() {
    // Redirect to a login screen if the user is not logged in
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

Widget buildLists(BuildContext context) {
  return selectedCategory == null
      ? _buildCategorySelector()
      : _buildSubcategorySelector();
}

// Category Selection UI
Widget _buildCategorySelector() {
  // Use a Map to store category name and imageUrl pairs
  Map<String, String> categoryMap = {};
  for (var product in products) {
    for (var category in product.categories) {
      categoryMap[category.name] = category.imageUrl;
    }
  }
  if (categoryMap.isEmpty) {
    return const Center(
      child: Text('No categories available', style: TextStyle(fontSize: 18)),
    );
  }
  final screenWidth = MediaQuery.of(context).size.width;
  final aspectRatio = screenWidth > 600 ? 2 : 1.5; // Adjusted for image + text
  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10.0,
      mainAxisSpacing: 10.0,
      childAspectRatio: aspectRatio as double,
    ),
    itemCount: categoryMap.length,
    itemBuilder: (context, index) {
      String category = categoryMap.keys.elementAt(index);
      String imageUrl = categoryMap[category] ?? 'https://via.placeholder.com/150'; // Fallback image
      return GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = category;
            selectedSubcategories.clear();
          });
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: selectedCategory == category ? Colors.blue.withOpacity(0.1) : Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  height: 60, // Fixed height for consistency
                  width: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 60),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selectedCategory == category ? Colors.blue : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Subcategory Selection UI
Widget _buildSubcategorySelector() {
  // Get subcategories with their imageUrls for the selected category
  Map<String, String> subcategoryMap = {};
  for (var product in products.where((p) => p.categories.any((c) => c.name == selectedCategory))) {
    var category = product.categories.firstWhere((c) => c.name == selectedCategory!);
    for (var subcategory in category.subcategories) {
      subcategoryMap[subcategory.name] = subcategory.imageUrl;
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with back button
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  selectedCategory = null;
                  selectedSubcategories.clear();
                });
              },
            ),
            Text(
              selectedCategory!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
          ],
        ),
      ),
      // Subcategory grid or product grid
      subcategoryMap.isEmpty || selectedSubcategories.isNotEmpty
          ? _buildProductGrid()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 1.5, // Adjusted for image + text
                ),
                itemCount: subcategoryMap.length,
                itemBuilder: (context, index) {
                  String subcategory = subcategoryMap.keys.elementAt(index);
                  String imageUrl = subcategoryMap[subcategory] ?? 'https://via.placeholder.com/150'; // Fallback image
                  bool isSelected = selectedSubcategories.contains(subcategory);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedSubcategories.remove(subcategory);
                        } else {
                          selectedSubcategories.add(subcategory);
                        }
                      });
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              imageUrl,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subcategory,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Colors.blue : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    ],
  );
}  
// Product Grid UI with Filters
Widget _buildProductGrid() {
  List<Product> productsToShow = _applyFiltersAndSort(products);
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(selectedCategory!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  selectedCategory = null;
                  selectedSubcategories.clear();
                });
              },
            ),
          ],
        ),
      ),
      _buildFilterAndSortControls(),
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
            childAspectRatio: 0.75,
          ),
          itemCount: productsToShow.length,
          itemBuilder: (context, index) {
            return _buildProductCard(productsToShow[index], isGrid: true);
          },
        ),
      ),
    ],
  );
}

Widget _buildFilterAndSortControls() {
  List<String> subcategories = products
      .where((p) => p.categories.any((c) => c.name == selectedCategory))
      .expand((p) => p.categories
          .firstWhere((c) => c.name == selectedCategory)
          .subcategories
          .map((s) => s.name))
      .toSet()
      .toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Subcategory Selector
      if (subcategories.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Subcategories", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Wrap(
          spacing: 8.0,
          children: subcategories.map((subcategory) => ChoiceChip(
            label: Text(subcategory),
            selected: selectedSubcategories.contains(subcategory),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  selectedSubcategories.add(subcategory);
                } else {
                  selectedSubcategories.remove(subcategory);
                }
              });
            },
          )).toList(),
        ),
      ],
      // Price Filter
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Price Range", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      RangeSlider(
        values: RangeValues(minPrice!, maxPrice!),
        min: 0.0,
        max: 1000.0,
        onChanged: (values) {
          setState(() {
            minPrice = values.start;
            maxPrice = values.end;
          });
        },
      ),
      Text('Price: \$${minPrice!.toStringAsFixed(2)} - \$${maxPrice!.toStringAsFixed(2)}'),
      // Sort Dropdown
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      DropdownButton<String>(
        value: sortBy,
        onChanged: (newValue) {
          setState(() {
            sortBy = newValue!;
          });
        },
        items: [
          'default',
          'priceLow',
          'priceHigh',
          'weather',
          'consumptionTime',
          'newest',
          'trending',
          'inSeason',
          'organic',
          'ecofriendly',
          'discounted'
        ].map((value) => DropdownMenuItem(
          value: value,
          child: Text(
            value == 'default' ? 'Default'
                : value == 'priceLow' ? 'Price: Low to High'
                : value == 'priceHigh' ? 'Price: High to Low'
                : value == 'weather' ? 'Weather Suitability'
                : value == 'consumptionTime' ? 'Time of Consumption'
                : value == 'newest' ? 'Newest Products'
                : value == 'trending' ? 'Trending Products'
                : value == 'inSeason' ? 'In Season'
                : value == 'organic' ? 'Organic First'
                : value == 'ecofriendly' ? 'Eco-Friendly First'
                : 'Discounted First',
          ),
        )).toList(),
      ),
    ],
  );
}

List<Product> _applyFiltersAndSort(List<Product> products) {
  // Current date for season and new product checks
  final DateTime now = DateTime.now();
  final DateTime twoMonthsAgo = DateTime(now.year, now.month - 2, now.day);

  // First apply filters
  List<Product> filtered = products.where((product) {
    if (!product.categories.any((c) => c.name == selectedCategory)) return false;
    if (product.basePrice < minPrice! || product.basePrice > maxPrice!) return false;
    if (selectedSubcategories.isNotEmpty) {
      Category category = product.categories.firstWhere((c) => c.name == selectedCategory!);
      if (!category.subcategories.any((s) => selectedSubcategories.contains(s.name))) return false;
    }
    return true;
  }).toList();

  // Then apply sorting
  return filtered..sort((a, b) {
    switch (sortBy) {
      case 'priceLow':
        return a.basePrice.compareTo(b.basePrice);
      case 'priceHigh':
        return b.basePrice.compareTo(a.basePrice);
      case 'weather':
        return (b.weather?.length ?? 0).compareTo(a.weather?.length ?? 0);
      case 'consumptionTime':
        return (b.consumptionTime?.length ?? 0).compareTo(a.consumptionTime?.length ?? 0);
      case 'newest':
        // Sort by products added in the last 2 months based on createdAt
        bool aIsNew = a.createdAt != null && a.createdAt!.isAfter(twoMonthsAgo);
        bool bIsNew = b.createdAt != null && b.createdAt!.isAfter(twoMonthsAgo);
        if (aIsNew == bIsNew) {
          return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
        }
        return aIsNew ? -1 : 1;
      case 'trending':
        return b.recentPurchaseCount.compareTo(a.recentPurchaseCount);
      case 'inSeason':
        // Check if currently in season based on seasonStart and seasonEnd
        bool aInSeason = a.isSeasonal &&
            a.seasonStart != null &&
            a.seasonEnd != null &&
            now.isAfter(a.seasonStart!) &&
            now.isBefore(a.seasonEnd!);
        bool bInSeason = b.isSeasonal &&
            b.seasonStart != null &&
            b.seasonEnd != null &&
            now.isAfter(b.seasonStart!) &&
            now.isBefore(b.seasonEnd!);
        if (aInSeason == bInSeason) return 0;
        return aInSeason ? -1 : 1;
      case 'organic':
        if (a.isOrganic == b.isOrganic) return 0;
        return a.isOrganic ? -1 : 1;
      case 'ecofriendly':
        if (a.isEcoFriendly == b.isEcoFriendly) return 0;
        return a.isEcoFriendly ? -1 : 1;
      case 'discounted':
        if (a.hasDiscounts == b.hasDiscounts) {
          return b.discountedPrice.compareTo(a.discountedPrice);
        }
        return a.hasDiscounts ? -1 : 1;
      case 'default':
      default:
        return 0;
    }
  });
}

  Future<void> fetchHealthBenefits(Product? product) async {
    setState(() {
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
      });
    } else {
      setState(() {
        _healthBenefits = "Failed to fetch health benefits. Try again!";
      });
    }
  }

  Future<void> fetchJoke(Product? product) async {
    setState(() {
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
      });
    } else {
      setState(() {
        _joke = "Failed to fetch a joke. Try again!";
      });
    }
  }

  Future<void> fetchProductJourney(Product? product) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
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
      });
    } else {
      setState(() {
        _dynamicJourney = "Failed to fetch product journey. Try again!";
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
            randomProduct.pictureUrl,
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
                basePrice: 0.0,
                description: '',
                categories: [],
                units: '',
                discountedPrice: 0.0,
              )
            : null;

        return Card(
          elevation: 5,
          child: Stack(
            children: [
              // Background image
              if (product != null)
                Image.network(
                  product.pictureUrl,
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
        basePrice: 0.0,
        description: '',
        categories: [],
        units: '',
        discountedPrice: 0.0,
      );
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
            randomProduct.pictureUrl,
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
            randomProduct.pictureUrl,
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
    final productImageUrl = product!.pictureUrl.isNotEmpty
        ? product.pictureUrl
        : 'assets/images/basket.png';
    final productName = product.name.isNotEmpty ? product.name : 'Mystery Item';
    final productCategory = product.categories.isNotEmpty
        ? product.categories.first.name
        : 'General';
    final productReviewCount = product.reviewCount;
    final productUnits = product.units;
    final productPrice = product.discountedPriceStream2 != null
        ? '\$${product.discountedPrice}'
        : 'Discover';
    double? originalPrice =
        product.basePrice; // Assuming you have an original price

    String? couponDiscount;
    // Calculate discount percentage if both prices are available
    String? discountPercentage;
    double? discountedPrice;

    // Check variety's discounted price first
    if (product.variety != null &&
        product.variety!.discountedPriceStream != null) {
      discountedPrice = product.variety!.discountedPrice;
    } else if (product.discountedPriceStream2 != null) {
      discountedPrice = product.discountedPrice as double?;
    }

    if (discountedPrice != null && originalPrice > discountedPrice) {
      double percentage =
          ((originalPrice - discountedPrice) / originalPrice) * 100;
      discountPercentage = '-${percentage.toStringAsFixed(0)}%';
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
    if (product.reviewCount > highlyRatedThreshold) {
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
            builder: (_) => ProductScreen(productId: product.id),
          ),
        );
        _logProductView;
        _logTimeSpent;
        _logClick(product, 'product_Screen');
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
                  productImageUrl,
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
    if (product!.reviews != null && product!.reviews!.isNotEmpty) {
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
                                    .imageUrl // Removed incorrect '\$' and unnecessary string interpolation
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
                                          selectedVariety?.discountedPrice != null
                                      ? '\$${selectedVariety!.discountedPrice}'
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
                                    Container(
                                      width: 25,
                                      height: 25,
                                      margin: const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          variety.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.error, size: 24),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(variety.name),
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
                                                      ' \$${selectedVariety!.price.toStringAsFixed(2) ?? 'N/A'}',
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
                                                    ? ' \$${selectedVariety!.discountedPrice?.toStringAsFixed(2) ?? 'N/A'}'
                                                    : selectedVariety!.price !=
                                                            null
                                                        ? ' \$${selectedVariety!.price.toStringAsFixed(2)}'
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
                  if (offer != null && product!.id == offer!.productId)
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
                          offer!.title,
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
                              _requestStockNotification(product!.id);
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
                          if (product!.genomicAlternatives.isNotEmpty)
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
                                ...product!.genomicAlternatives
                                    .map((alternative) {
                                  return ListTile(
                                    leading: Image.network(
                                      alternative.pictureUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                    title: Text(
                                      alternative.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    subtitle: Text(
                                      'Price: ${alternative.basePrice}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProductScreen(
                                              productId: alternative.id),
                                        ),
                                      );
                                    },
                                  );
                                }),
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
                  builder: (_) => ProductScreen(productId: product.id),
                ),
              );
              _logProductView;
              _logTimeSpent;
              _logClick(product, 'product_Screen');
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
    if (_userProvider.user.isAdmin ||
        _userProvider.user.isRider ||
        _userProvider.user.isAttendant) {
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
              if (_userProvider.user.isAdmin && !_userProvider.user.isRider) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen()));
              } else if (_userProvider.user.isRider) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PendingDeliveriesScreen()));
              } else if (_userProvider.user.isAttendant) {
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
Widget _buildTagsSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Explore by Tags'),
        SizedBox(
          height: 40.0, // Fixed height for horizontal scroll of tags
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allTags.length + 1, // +1 for "Clear" chip
            itemBuilder: (context, index) {
              if (index == 0) {
                // "Clear" chip to reset filter
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: const Text('Clear'),
                    backgroundColor: selectedTag == null ? Colors.blue : Colors.grey,
                    labelStyle: TextStyle(color: selectedTag == null ? Colors.white : Colors.black),
                    onPressed: _clearTagFilter,
                  ),
                );
              }
              final tag = allTags[index - 1];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(tag),
                  backgroundColor: selectedTag == tag ? Colors.blue : null,
                  labelStyle: TextStyle(color: selectedTag == tag ? Colors.white : Colors.black),
                  onPressed: () => _filterProductsByTag(tag),
                ),
              );
            },
          ),
        ),
        // Display filtered products in a grid if a tag is selected
        if (selectedTag != null && tagFilteredProducts.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Products tagged "$selectedTag"'),
              GridView.builder(
                shrinkWrap: true, // Important for nesting in SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(), // Disable inner scrolling
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 columns for grid
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 0.75, // Adjust as needed for card proportions
                ),
                itemCount: tagFilteredProducts.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(tagFilteredProducts[index], isGrid: true);
                },
              ),
            ],
          )
        else if (selectedTag != null && tagFilteredProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No products found for this tag.'),
          ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    User? user;


    Future<List<Product>> predictedProducts = predictProducts(
      recentlyBought,
      products,
      nearbyUsersBought,
      seasonallyAvailable,
    );



    return Scaffold(
      body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned:
                    true, // Ensures that the app bar remains visible as the user scrolls.

                title: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          final containerSize = (screenWidth * 0.25).clamp(40.0, 100.0);
                          final lottieSize = (containerSize * 0.8).clamp(30.0, 80.0);

                          return GlassmorphicContainer(
                            width: containerSize,
                            height: containerSize,
                            borderRadius: 20,
                            blur: 15,
                            alignment: Alignment.center,
                            border: 2,
                            linearGradient: LinearGradient(
                              colors: [
                                Colors.lightGreenAccent.withOpacity(0.2),
                                Colors.orange.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderGradient: LinearGradient(
                              colors: [
                                Colors.redAccent.withOpacity(0.4),
                                Colors.purpleAccent.withOpacity(0.2),
                                Colors.pinkAccent.withOpacity(0.1),
                              ],
                            ),
                            child: Lottie.network(
                              'https://lottie.host/f0e504ff-1b4a-43d1-a08c-93fa0aa5e4ae/6xKWN4vKCF.json',
                              height: lottieSize,
                              width: lottieSize,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8), // Spacing between logo and title
                    const Flexible(
                      child: AutoSizeText(
                            'SOKONI\'S!',
                            style: TextStyle(fontSize: 36), // Max size
                            minFontSize: 14,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )

                    ),
                  ],
                ),
                actions: [
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2,
                          0.005) // Stronger perspective for better 3D effect
                      ..rotateX(0.15) // Increase to ~8.6 degrees for visibility
                      ..scale(1.1), // Optional: slight scale-up for emphasis
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
                            if (_userProvider.isLoggedIn() == true) {  // Add parentheses to execute the function
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
                      ..setEntry(3, 2, 0.005) // Stronger perspective
                      ..rotateY(-0.3), // More pronounced Y tilt
                    alignment: Alignment.center,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2,
                                0.005) // Stronger perspective for better 3D effect
                            ..rotateX(
                                0.15) // Increase to ~8.6 degrees for visibility
                            ..scale(
                                1.1), // Optional: slight scale-up for emphasis // Slight scale for emphasis
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
                      ..setEntry(3, 2,
                          0.005) // Stronger perspective for better 3D effect
                      ..rotateX(0.15) // Increase to ~8.6 degrees for visibility
                      ..scale(1.1), // Optional: slight scale-up for emphasis
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
                      ..setEntry(3, 2,
                          0.005) // Stronger perspective for better 3D effect
                      ..rotateX(0.15) // Increase to ~8.6 degrees for visibility
                      ..scale(1.1), // Optional: slight scale-up for emphasis
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
                      ..setEntry(3, 2,
                          0.005) // Stronger perspective for better 3D effect
                      ..rotateX(0.15) // Increase to ~8.6 degrees for visibility
                      ..scale(1.1), // Optional: slight scale-up for emphasis
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return IconButton(
                          tooltip: 'Cart', // Tooltip for the shopping cart.
                          icon: const Icon(Icons.shopping_cart),
                          onPressed: () {
                            setState(() {
                              // Code to modify the background color if required.
                            });
                            if (_userProvider.isLoggedIn() == true) {  // Add parentheses to execute the function
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

                _buildTagsSection(), // Updated tags section with grid
                // Check if there are offers and no search query
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
                                          productId: offer.productId),
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
                                          offer.imageUrl,
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
                                                  offer.title,
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
                                    return _buildProductCard(filteredProducts[index],
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
                  for (String category in categoryProducts!.keys) ...[
                    _buildSectionTitle(category),
                    _buildCategorySelector(),
                  ],
                ],
              ],
            ),
          )),
      // FloatingActionButton logic for Admin, Rider, or Attendant users
      floatingActionButton: _userProvider.user.isAdmin ||
              _userProvider.user.isRider ||
              _userProvider.user.isAttendant
          ? _buildFloatingActionButton(context)
          : null,
    );
  }
}


class IconDetail {
  IconDetail({this.image, required this.head, this.icon});

  final String head;
  final String? image;
  final Icon? icon;
}

class Debouncer {
  late final int milliseconds;
  VoidCallback? _action;
  Timer? _timer;

  Debouncer(this.milliseconds);

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
