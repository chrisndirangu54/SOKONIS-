import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grocerry/models/notification_model.dart';
import 'package:grocerry/screens/notification_screen.dart';
import 'package:grocerry/screens/offers_page.dart';
import 'package:lottie/lottie.dart';
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
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/offer_provider.dart';
import '../utils.dart';
import 'package:grocerry/services/ai_service.dart';
import 'package:collection/collection.dart'; // Add this import for ListEquality
import 'package:glassmorphism/glassmorphism.dart';
import '../services/notification_service.dart'; // Adjust path as needed
import 'package:fuzzy/fuzzy.dart'; // Ensure you have the fuzzy package imported

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late ProductProvider _productProvider;
  late OfferProvider _offerProvider;
  late UserProvider _userProvider;
  late AuthProvider _authProvider;
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> notifications = [];
  List<String> previouslySearchedProducts =
      []; // Cache for previously searched products

  List<Product> products = [];
  List<Product> filteredProducts = [];
  List<Product> recentlyBought = [];
  List<Product> favorites = [];
  List<Product> categoryProducts = [];
  List<Product> seasonallyAvailable = [];
  List<Product> nearbyUsersBought = [];
  List<Product> predictedProducts = [];
  List<String> searchSuggestions = [];
  List<Product> complementaryProducts = [];
  List<Offer> offers = [];
  Timer? _debounce;
  Timer? _autoScrollTimer;
  bool _userIsInteracting = false;
  String? selectedCategory;
  final UserAnalyticsService _userAnalyticsService = UserAnalyticsService();
  int _unreadNotificationsCount = 0;

  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSearching = false;
  bool _hasInitialSuggestions = false;
  bool _isHovered = false;
  bool _isFlipped = false;
  bool _isPressed = false;
  late List<Product> user;

  List<Category>? categories = []; // Track if initial suggestions are provided.

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning $user';
    } else if (hour < 17) {
      return 'Good afternoon $user';
    } else {
      return 'Good evening $user';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productProvider = Provider.of<ProductProvider>(context);
    _offerProvider = Provider.of<OfferProvider>(context);
    _userProvider = Provider.of<UserProvider>(context);
    // _authProvider = Provider.of<AuthProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProducts();
    });
    searchController.addListener(_filterProducts); // Adding search listener

    // Start auto-scrolling
    _startAutoScroll();
    _scrollController.addListener(() {
      if (_scrollController.position.isScrollingNotifier.value) {
        _userIsInteracting = true;
        _stopAutoScroll();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.isScrollingNotifier.value) {
        _userIsInteracting = true;
        _stopAutoScroll(); // Stop auto-scrolling on user interaction
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeProducts() async {
    try {
      // Check if providers are initialized
      if (_productProvider == null ||
          _userProvider == null ||
          _offerProvider == null) {
        throw Exception(
          "Missing provider: ${_productProvider == null ? "ProductProvider, " : ""}${_userProvider == null ? "UserProvider, " : ""}${_offerProvider == null ? "OfferProvider" : ""}",
        );
      }

      // Use a list of futures that correctly returns the types
      var futureList = [
        _productProvider.fetchProducts(),
        _productProvider.fetchNearbyUsersBought(),
        _productProvider.fetchSeasonallyAvailable(),
        if (_userProvider.isLoggedIn()) ...[
          _userProvider.fetchFavorites(),
          _userProvider.fetchRecentlyBought(),
        ],
        _offerProvider.fetchOffers(),
      ];

      // Handle potential errors in futures
      List<List<dynamic>> results =
          await Future.wait(futureList as Iterable<Future<List>>);

      // Storing the results in class properties with proper casting
      products = results[0] as List<Product>? ?? [];
      nearbyUsersBought = results[1] as List<Product>? ?? [];
      seasonallyAvailable = results[2] as List<Product>? ?? [];
      favorites = results[3] as List<Product>? ?? [];
      recentlyBought = results[4] as List<Product>? ?? [];
      offers = results[5] as List<Offer>? ?? [];

      // Update UI after fetching data
      setState(() {});
    } catch (e, stackTrace) {
      print("Error initializing providers, falling back to utils.dart: $e");
      print("Stack trace: $stackTrace");
      await _fetchFallbackProducts();
    }
  }

  Future<void> _fetchFallbackProducts() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      // Dynamically map the itemList and apply conditions
      if (itemList.isNotEmpty) {
        setState(() {
          products = itemList.map((item) => item as Product).toList();

          recentlyBought =
              products.where((product) => product.reviewCount > 40).toList();

          favorites =
              products.where((product) => product.basePrice < 1.0).toList();

          filteredProducts = products;
        });
      } else {
        print("itemList is empty or null in fallback");
      }
    } catch (e) {
      print("Error fetching fallback products: $e");
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
              FuzzyOptions<Category>(shouldSort: true);

          // Create Fuzzy objects for products, offers, and categories
          final fuzzyProducts =
              Fuzzy<Product>(products, options: fuzzyOptionsForProducts);
          final fuzzyOffers =
              Fuzzy<Offer>(offers, options: fuzzyOptionsForOffers);
          final fuzzyCategories =
              Fuzzy<Category>(categories, options: fuzzyOptionsForCategories);

          // Use fuzzy matching to filter products across different categories
          List<Product> nearbyResults =
              fuzzyProducts.search(query).map((result) => result.item).toList();

          // Perform fuzzy searches for seasonally available, favorites, and recently bought separately
          List<Product> seasonalResults = Fuzzy<Product>(seasonallyAvailable,
                  options: fuzzyOptionsForProducts)
              .search(query)
              .map((result) => result.item)
              .toList();
          List<Product> favoriteResults =
              Fuzzy<Product>(favorites, options: fuzzyOptionsForProducts)
                  .search(query)
                  .map((result) => result.item)
                  .toList();
          List<Product> recentlyBoughtResults =
              Fuzzy<Product>(recentlyBought, options: fuzzyOptionsForProducts)
                  .search(query)
                  .map((result) => result.item)
                  .toList();

          // Filter products using similarity check
          nearbyResults.addAll(nearbyUsersBought
              .where((product) => product.name.similarityTo(query) > 0.5)
              .toList());
          seasonalResults.addAll(seasonallyAvailable
              .where((product) => product.name.similarityTo(query) > 0.5)
              .toList());
          favoriteResults.addAll(favorites
              .where((product) => product.name.similarityTo(query) > 0.5)
              .toList());
          recentlyBoughtResults.addAll(recentlyBought
              .where((product) => product.name.similarityTo(query) > 0.5)
              .toList());

          // Identify complementary products
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
          List<Category> categoryResults = fuzzyCategories
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
            ...offerResults.map((offer) => offer.title),
            ...categoryResults.map((category) => category as String),
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

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_userIsInteracting) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  Future<List<Product>> predictProducts(
    String userId, // User identifier
    List<Product> recentlyBought,
    List<Product> products,
    List<Product> nearbyUsersBought,
    List<Product> seasonallyAvailable,
  ) async {
    // Gather complementary products based on nearby users' bought products
    List<Product> complementaryProducts = [];
    for (Product trending in nearbyUsersBought) {
      complementaryProducts.addAll(
        products.where((p) => trending.isComplementaryTo(p)),
      );
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
    for (var product in combinedPrediction) {
      final userAnalytics = await _userAnalyticsService.getUserProductAnalytics(
          userId, product.id);
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
        return b.userTimeSpent.compareTo(a.userTimeSpent);
      } else {
        return b.userViews.compareTo(a.userViews);
      }
    });

    // Return only the top 10 products based on user activity
    return productsWithUserAnalytics.take(10).toList();
  }

// Function to create hint text based on suggestions
  String _getHintText() {
    final suggestions = _getSearchSuggestions(context); // Fetch suggestions
    if (suggestions.isNotEmpty) {
      return suggestions
          .join(', '); // Join suggestions into a comma-separated string
    }
    return 'Search products...'; // Default hint text
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final isHomeScreen = ModalRoute.of(context)?.settings.name ==
        '/home'; // Adjust the route name as needed

    Future<List<Product>> predictedProducts = predictProducts(
        recentlyBought as String,
        products,
        nearbyUsersBought,
        user,
        seasonallyAvailable);

    // Group products by category
    Map<String, List<Product>> categoryProducts = {};
    for (var product in products) {
      // Use all products, not filtered ones, for categories
      if (!categoryProducts.containsKey(product.category)) {
        categoryProducts[product.category] = [];
      }
      categoryProducts[product.category]!.add(product);
    }

    return Scaffold(
      appBar: AppBar(
        leading: isHomeScreen
            ? null // No back button if on home screen
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop(); // Go back to the previous screen
                },
              ),
        title: Row(
          children: [
            GestureDetector(
              onTapDown: (_) {
                // Triggering the animation when pressed
              },
              onTapUp: (_) {
                // Logic can be added if needed on release
              },
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2), // Shadow color
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(
                          0, 4), // Shadow position (horizontal, vertical)
                    ),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 0.1),
                  duration: const Duration(
                      milliseconds: 500), // Duration for the bounciness
                  curve: Curves.elasticInOut, // Elastic effect
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
                            Colors.white.withOpacity(0.05)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderGradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.1)
                          ],
                        ),
                        child: Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Perspective
                            ..rotateY(tiltValue) // Subtle 3D rotation on Y-axis
                            ..rotateX(
                                tiltValue), // Subtle 3D rotation on X-axis
                          alignment: FractionalOffset.center,
                          child: Lottie.network(
                            'https://lottie.host/f0e504ff-1b4a-43d1-a08c-93fa0aa5e4ae/6xKWN4vKCF.json',
                            height: 40,
                            width: 40,
                            fit: BoxFit.contain,
                          ),
                        ));
                  },
                ),
              ),
            ),
            const SizedBox(
                width: 8), // Add some space between the logo and title
            const Text('SOKONI\'S!'),
          ],
        ),
        actions: [
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect for 3D
              ..rotateY(0.1), // Slight rotation along Y-axis
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                if (_userProvider.isLoggedIn()) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const ProfileScreen()));
                } else {
                  _redirectToLogin();
                }
              },
            ),
          ),
          // Inside your build method, where you're defining your AppBar actions:
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect for 3D
              ..rotateY(
                  -0.1), // Slight rotation along Y-axis, opposite direction for variety
            alignment: Alignment.center,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective effect
                  ..rotateX(
                      -0.05), // Slight tilt for 3D effect, opposite direction
                child: IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications),
                      if (_unreadNotificationsCount >
                          0) // Show badge only if there are unread notifications
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
                              '$_unreadNotificationsCount', // Show the actual unread count
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
                  onPressed:
                      _onNotificationPressed, // Define what happens when the notification icon is pressed
                  iconSize: 30,
                  tooltip: 'Notifications',
                )),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect
              ..rotateX(0.05), // Slight tilt for 3D effect
            child: IconButton(
              icon: const Icon(Icons.message_rounded),
              onPressed: _openWhatsApp,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect
              ..rotateX(0.05), // Slight tilt for 3D effect
            child: IconButton(
              icon: const Icon(Icons.local_offer), // Change icon as needed
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const OffersPage(), // Navigate to OffersPage
                  ),
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect
              ..rotateX(0.05), // Slight tilt for 3D effect
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                if (_userProvider.isLoggedIn()) {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()));
                } else {
                  _redirectToLogin();
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
              100.0), // Fixed height for the AppBar bottom
          child: Container(
            height: 100.0, // Ensure the height matches the preferred size
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back button to exit search mode
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: mainColor),
                      onPressed: () {
                        setState(() {
                          isSearching = false; // Exit search mode
                          searchController
                              .clear(); // Clear search input when exiting
                          _hasInitialSuggestions =
                              false; // Reset suggestion flag
                        });
                      },
                    ),
                    // Search TextField
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText:
                              "Search For... ${_getHintText()}", // Dynamically set hint text
                          prefixIcon: Icon(Icons.search,
                              color:
                                  mainColor), // Search icon inside the text field
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: mainColor),
                                  onPressed: () {
                                    setState(() {
                                      searchController
                                          .clear(); // Clear search input
                                      _filterProducts(); // Reset filtered products
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filterProducts(); // Update suggestions and filtered products based on input
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Display horizontal suggestions when typing
                if (searchController.text.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis
                          .horizontal, // Horizontal scrolling for suggestions when typing
                      child: Wrap(
                        spacing: 8.0, // Spacing between suggestion chips
                        children:
                            _getSearchSuggestions(context).map((suggestion) {
                          return ActionChip(
                            key: ValueKey(
                                suggestion), // Ensure unique key for each suggestion
                            label: Text(
                              suggestion,
                              style: const TextStyle(
                                fontSize:
                                    14.0, // Fixed font size for suggestion chips
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                searchController.text =
                                    suggestion; // Fill the search field with the suggestion
                                _filterProducts(); // Reapply filtering when a suggestion is selected
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Stretch for full width
          children: [
            Column(
              children: [
                _buildSectionTitle(
                    '${_getGreeting()}, ${user?.name ?? 'Guest'}!'),
              ],
            ),
            if (offers.isNotEmpty && searchController.text.isEmpty)
              Column(
                children: [
                  _buildSectionTitle('Special Offers'),
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 250.0,
                      autoPlay: true,
                      viewportFraction:
                          0.8, // Smaller fraction for a more focused center item
                      autoPlayCurve: Curves.fastOutSlowIn,
                      enableInfiniteScroll: true,
                      autoPlayAnimationDuration:
                          const Duration(milliseconds: 800),
                      enlargeCenterPage: true,
                      enlargeStrategy: CenterPageEnlargeStrategy.scale,
                    ),
                    items: offers.map((offer) {
                      return Builder(
                        builder: (BuildContext context) {
                          return GestureDetector(
                            onTap: () {
                              // Navigate to product screen
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProductScreen(productId: offer.productId),
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
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
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
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return ListTile(
                            key: ValueKey(product.id),
                            title: Text(product.name),
                            onTap: () {
                              setState(() {
                                _userIsInteracting = true;
                                _stopAutoScroll();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProductScreen(productId: product.id),
                                  ),
                                );
                              });
                            },
                          );
                        },
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
              if (_userProvider.isLoggedIn()) ...[
                _buildSectionTitle('Recently Bought'),
                _buildHorizontalProductList(recentlyBought),
                _buildSectionTitle('Favorites'),
                _buildHorizontalProductList(favorites),
              ],

              _buildSectionTitle('Just For You!'),
              _buildHorizontalProductList(predictedProducts as List<Product>),
              // Products grouped by category in a grid
              _buildSectionTitle('Products by Category'),
              for (String category in categoryProducts.keys) ...[
                _buildSectionTitle(category),
                _buildCategorySelector(
                    categoryProducts[category]! as Map<String, List<Product>>),
              ],
            ],
          ],
        ),
      ),

      // FloatingActionButton logic for Admin, Rider, or Attendant users
      floatingActionButton: _userProvider.user.isAdmin ||
              _userProvider.user.isRider ||
              _userProvider.user.isAttendant
          ? _buildFloatingActionButton(context)
          : null,
    );
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
        ? _buildCategorySelector(categoryProducts as Map<String, List<Product>>)
        : _buildProductGrid(
            selectedCategory, categoryProducts as Map<String, List<Product>>);
  }

  // Widget to display categories as selectable options
  Widget _buildCategorySelector(Map<String, List<Product>> categoryProducts) {
    List<String> categories = categoryProducts.keys.toList();

    return categories.isEmpty
        ? _buildEmptyState() // In case there are no categories
        : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 3, // More horizontal space for category buttons
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              String category = categories[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category; // Set the selected category
                  });
                },
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(8.0),
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

  // Widget to display products in a grid for the selected category
  Widget _buildProductGrid(
      String? currentCategory, Map<String, List<Product>> categoryProducts) {
    List<Product> productsToShow = categoryProducts[currentCategory] ?? [];

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
                // Button to go back to category selection
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      selectedCategory = null; // Go back to category selection
                    });
                  },
                )
              ],
            ),
          ),
        productsToShow.isEmpty
            ? _buildEmptyState()
            : Expanded(
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
    return const Center(
      child: Text(
        "No products available",
        style: TextStyle(color: Colors.grey, fontSize: 18),
      ),
    );
  }

  Widget _buildProductCard(Product product, {required bool isGrid}) {
    final productImageUrl = product.pictureUrl.isNotEmpty
        ? product.pictureUrl
        : 'path/to/placeholder.jpg';
    final productName = product.name.isNotEmpty ? product.name : 'Mystery Item';
    final productCategory = product.category;
    final productReviewCount = product.reviewCount;
    final productUnits = product.units;
    final productPrice =
        product.basePrice != null ? '\$${product.basePrice}' : 'Discover';
    double? originalPrice =
        product.basePrice; // Assuming you have an original price
    double? discountedPrice = product.discountedPrice;
    String? couponDiscount;
    // Calculate discount percentage if both prices are available
    String? discountPercentage;
    if (originalPrice != null &&
        discountedPrice != null &&
        originalPrice > discountedPrice) {
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
    if (product != null && product.reviewCount > highlyRatedThreshold) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/StartOutline.svg', head: 'Highly\nRated'),
      );
    }

    // Conditionally add icons based on new fields
    if (product?.isFresh ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/FreshOutline.svg',
            head: 'Freshness\nGuaranteed'),
      );
    }

    if (product?.isLocallySourced ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/LocalOutline.svg', head: 'Locally\nSourced'),
      );
    }

    if (product?.isOrganic ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/OrganicOutline.svg', head: 'Organic\nChoice'),
      );
    }

    if (product?.hasHealthBenefits ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/HealthOutline.svg', head: 'Health\nBenefits'),
      );
    }

    if (product?.hasDiscounts ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/DiscountOutline.svg',
            head: 'Great\nDiscounts'),
      );
    }

    if (product?.isSeasonal ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/SeasonalOutline.svg',
            head: 'Seasonal\nFavorites'),
      );
    }

    if (product?.isEcoFriendly ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/GreenOutline.svg', head: 'Eco-Friendly'),
      );
    }

    if (product?.isSuperfood ?? false) {
      dynamicIconsList.add(
        IconDetail(
            image: 'assets/icons/SuperfoodOutline.svg', head: 'Superfoods'),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isFlipped = !_isFlipped;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          // Toggle hover effect based on vertical movement
          _isHovered = details.delta.dy > 0;
        });
      },
      child: MouseRegion(
        onEnter: (_) => setState(
            () => _isHovered = true), // Ensure `_isHovered` is declared.
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: _isFlipped
              ? (Matrix4.identity()
                ..rotateY(3.14)) // Proper parentheses grouping.
              : (Matrix4.identity()
                ..rotateX(_isHovered
                    ? -0.05
                    : 0) // Ensure both rotations are applied correctly.
                ..rotateY(_isHovered ? 0.05 : 0)),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: _isFlipped
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
                  productUnits),
        ),
      ),
    );
  }

  // Front side of the product card
  Widget _buildFrontSide(
    String productImageUrl,
    String productName,
    String productPrice,
    String? discountPercentage,
    double? originalPrice,
    bool inStock,
    String? couponDiscount, // New parameter for coupon discount
    String? productCategory,
    int? productReviewCount,
    String? productUnits,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Image.network(
                  productImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _buildLoadingShimmer(),
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error),
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
                    )),
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
                    Text(
                      "⭐ (${productReviewCount!} reviews)",
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
                              '\$$originalPrice', // Original price with strike-through
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          Text(
                            productPrice,
                            style: TextStyle(
                                color: Colors.orange.withOpacity(0.75),
                                fontSize: 16),
                          ),
                          Text(
                            "PER ${productUnits ?? ''}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 16),
                          )
                        ])
                  ],
                ),
              ),
            ],
          ),
          if (discountPercentage != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  discountPercentage,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (!inStock)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Coupon: $couponDiscount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
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
                        SvgPicture.asset(iconDetail.image,
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
}

class IconDetail {
  final String image;
  final String head;

  IconDetail({required this.image, required this.head});
}

extension on Object {}
