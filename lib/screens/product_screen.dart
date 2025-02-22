import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:grocerry/utils.dart';
import 'package:provider/provider.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart'; // For adding/removing favorites
import 'package:grocerry/providers/cart_provider.dart'; // For cart functionality
import 'review_screen.dart'; // Import the review screen
import 'package:grocerry/services/ai_service.dart';

class ProductScreen extends StatefulWidget {
  final String productId;

  Product? product;

  final dynamic varieties;

  ProductScreen(
      {super.key, required this.productId, this.product, this.varieties});

  @override
  ProductScreenState createState() => ProductScreenState();
}

class ProductScreenState extends State<ProductScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _viewStartTime;
  Variety? selectedVariety; // Track the selected variety
  late AnimationController _controller;
  late Subscription subscription;
  late SubscriptionService subscriptionService = SubscriptionService();
  Product? product;

  late final Animation<double> _scaleAnimation =
      Tween<double>(begin: 2.3, end: 2.7).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),
  );

  late final Animation<double> _rotationAnimation = Tween<double>(
          begin: 0, end: 3.14) // 3.14 radians for 180 degrees
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  // Control the state of the selected variety and image index
  int selectedVarietyIndex = 0; // Changed variable name
  int currentImageIndex = 0;
  
  var notes;

  get quantity => null;

  @override
  void initState() {
    super.initState();
    // Initialize the AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Adjust the duration as needed
    );
    // Fetch product and set default selected variety
    _logProductView(product);
    _viewStartTime = DateTime.now();
    _fetchProductAnalytics();
  }

  void _selectVariety(Variety variety) {
    setState(() {
      selectedVariety = variety;
    });
  }

  @override
  void dispose() {
    _logTimeSpent(product, _viewStartTime);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchProductAnalytics() async {
    final analyticsService = AnalyticsService();
    final analytics =
        await analyticsService.getProductAnalytics(widget.productId);

    setState(() {
      // Assuming 'product' is a local variable, so this part will need to be adapted
      // For example: Use a state management solution to fetch and store the product
    });
  }

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
  String? getCurrentImageUrl() {
    // Returns the image URL for the selected variety and image
    if (product!.varieties.isEmpty) {
      return product!.pictureUrl.isNotEmpty
          ? widget.product?.pictureUrl
          : 'https://example.com/default_image.png';
    }

    // Get the selected variety
    final selectedVariety = widget.varieties[selectedVarietyIndex];
    // Get the image URL of the current image index
    return currentImageIndex < selectedVariety.imageUrls.length
        ? selectedVariety.imageUrls[currentImageIndex]
        : selectedVariety.imageUrls.first; // Fallback to the first image
  }

  void _changeVariety() {
    // Update the selected variety index and reset the image index
    setState(() {
      selectedVarietyIndex = ((selectedVarietyIndex + 1) %
          widget.varieties.length) as int; // Changed variable name
      currentImageIndex = 0; // Reset to the first image of the new variety
      _controller.forward(from: 0); // Play spin animation
    });
  }

  void _nextImage() {
    // Update to the next image for the selected variety
    setState(() {
      final selectedVariety = widget.varieties[selectedVarietyIndex];
      currentImageIndex = ((currentImageIndex + 1) %
          selectedVariety.imageUrls.length) as int; // Cycle through images
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final productProvider = Provider.of<ProductProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final user = userProvider.user;
    final product = productProvider.getProductById(widget.productId);

    if (product == null) {
      return const Scaffold(body: Center(child: Text("Product not found")));
    }

    // Ensure the variety is initialized
    if (selectedVariety == null && product.varieties.isNotEmpty) {
      selectedVariety = product.varieties.first;
    }

    const int highlyRatedThreshold = 100;
    final int remainingStock = productProvider.getRemainingStock(product);
    final bool inStock = productProvider.isInStock(product);

    List<IconDetail> dynamicIconsList = [
      IconDetail(
          image: 'assets/icons/LikeOutline.svg', head: 'Quality\nAssurance'),
      IconDetail(
          image: 'assets/icons/SpoonOutline.svg', head: 'Best In\nTaste'),
    ];

    if (product.reviewCount > highlyRatedThreshold) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/StartOutline.svg', head: 'Highly\nRated'));
    }
    if (product.isFresh) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/FreshOutline.svg',
          head: 'Freshness\nGuaranteed'));
    }
    if (product.isLocallySourced) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/LocalOutline.svg', head: 'Locally\nSourced'));
    }
    if (product.isOrganic) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/OrganicOutline.svg', head: 'Organic\nChoice'));
    }
    if (product.hasHealthBenefits) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/HealthOutline.svg', head: 'Health\nBenefits'));
    }
    if (product.hasDiscounts) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/DiscountOutline.svg', head: 'Great\nDiscounts'));
    }
    if (product.isSeasonal) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/SeasonalOutline.svg',
          head: 'Seasonal\nFavorites'));
    }
    if (product.isEcoFriendly) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/GreenOutline.svg', head: 'Eco-Friendly'));
    }
    if (product.isSuperfood) {
      dynamicIconsList.add(IconDetail(
          image: 'assets/icons/SuperfoodOutline.svg', head: 'Superfoods'));
    }

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        elevation: 0,
        leadingWidth: 60,
        backgroundColor: primaryColor,
        toolbarHeight: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: GestureDetector(
              onTap: () {
                _logClick(product);
                Navigator.pushNamed(context, '/cart');
              },
              child: CircleAvatar(
                radius: 25,
                backgroundColor: const Color.fromARGB(255, 90, 90, 90),
                child: SvgPicture.asset(
                  'assets/icons/cartIcon.svg',
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: screenHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Text(
                product.category,
                style: TextStyle(
                    fontSize: 20, color: mainColor, letterSpacing: 10),
              ),
              Image.network(
                product.categoryImageUrl,
                height: 60,
                width: 60,
              ),
              const SizedBox(height: 10),

              // Product name
              Text(
                product.name,
                style:
                    const TextStyle(fontSize: 16), // Adjust font size as needed
              ),
              // Subscribe icon button
              IconButton(
                icon: Icon(
                  Icons.notifications, // Icon for subscription
                  color: subscription
                          .isActive // Assuming subscription is a Subscription object
                      ? Colors.orange // Active subscription color
                      : Colors.grey, // Inactive subscription color
                ),
                onPressed: () {
                  // Call _askForSubscription with the product ID
                  _askForSubscription(product);
                  // Toggle subscription status

                  setState(() {}); // Update UI
                },
                tooltip: subscription.isActive
                    ? 'Unsubscribe' // Tooltip when active
                    : 'Subscribe', // Tooltip when inactive
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  _logClick(product);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) =>
                            ReviewScreen(productId: product.id)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(
                      8), // Adjust padding for visual space
                  decoration: BoxDecoration(
                    color: primaryColor, // Background color of the container
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    border: Border.all(
                      color: Colors
                          .lightGreenAccent, // Border color to make it visible
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    "⭐ (${product.reviewCount} reviews)",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.blueGrey, // To indicate it's clickable
                      decoration: TextDecoration
                          .underline, // Underline for clickable text
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const SizedBox(height: 150),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(screenWidth / 2.7),
                      topRight: Radius.circular(screenWidth / 2.7),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 55),
                    child: Column(
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _nextImage, // Change to next image on tap
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Layer 1 - Bottom image with slight offset and animation
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Transform(
                                          alignment: Alignment
                                              .bottomCenter, // Align rotation to the bottom center
                                          transform: Matrix4.identity()
                                            ..translate(
                                                -50, 0) // Move to the left edge
                                            ..rotateZ(_rotationAnimation
                                                .value) // Rotate
                                            ..translate(0,
                                                -45) // Apply vertical offset to simulate emerging from the bottom
                                            ..scale(_scaleAnimation
                                                .value), // Animated zoom effect
                                          child: Image.network(
                                            getCurrentImageUrl() ?? 'https://example.com/default_image.png',
                                            height: 100,
                                            width: 100,
                                            color: Colors.black.withOpacity(
                                                0.5), // Shadow effect
                                            colorBlendMode: BlendMode.darken,
                                          ),
                                        );
                                      },
                                    ),

                                    // Layer 2 - Middle image with slight offset
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Transform(
                                          alignment: Alignment
                                              .bottomCenter, // Align rotation to the bottom center
                                          transform: Matrix4.identity()
                                            ..translate(
                                                -50, 0) // Move to the left edge
                                            ..rotateZ(_rotationAnimation
                                                .value) // Rotate
                                            ..translate(
                                                0, -35) // Apply vertical offset
                                            ..scale(_scaleAnimation.value +
                                                0.2), // Slightly larger scale
                                          child: Image.network(
                                            getCurrentImageUrl() ?? 'https://example.com/default_image.png',
                                            height: 100,
                                            width: 100,
                                            color: Colors.black.withOpacity(
                                                0.3), // Shadow effect
                                            colorBlendMode: BlendMode.darken,
                                          ),
                                        );
                                      },
                                    ),

                                    // Layer 3 - Top image (Main) with zoom effect
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Transform(
                                          alignment: Alignment
                                              .bottomCenter, // Align rotation to the bottom center
                                          transform: Matrix4.identity()
                                            ..translate(
                                                -50, 0) // Move to the left edge
                                            ..rotateZ(_rotationAnimation
                                                .value) // Rotate
                                            ..translate(
                                                0, -25) // Apply vertical offset
                                            ..scale(_scaleAnimation.value +
                                                0.4), // Main scale effect
                                          child: Image.network(
                                            getCurrentImageUrl() ?? 'https://example.com/default_image.png',
                                            height: 100,
                                            width: 100,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16), // Spacing
                                ElevatedButton(
                                  onPressed: _changeVariety,
                                  child: const Text(
                                      'Next Variety'), // Button to change variety
                                ),
                              ]),
                            )
                          ],
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (selectedVariety != null &&
                                    selectedVariety!.discountedPrice !=
                                        null) ...[
                                  Text(
                                    '\$${selectedVariety!.price}',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: mainColor.withOpacity(0.6),
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '\$${selectedVariety!.discountedPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.green, fontSize: 35),
                                  ),
                                ] else if (product.hasDiscounts &&
                                    selectedVariety != null) ...[
                                  Text(
                                    '\$${selectedVariety!.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 35),
                                  ),
                                ] else if (product.hasDiscounts) ...[
                                  Text(
                                    '\$${product.basePrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: mainColor.withOpacity(0.6),
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '\$${product.discountedPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.green, fontSize: 35),
                                  ),
                                ] else ...[
                                  Text(
                                    selectedVariety != null
                                        ? '\$${selectedVariety!.price.toStringAsFixed(2)}'
                                        : '\$${product.basePrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: selectedVariety != null
                                          ? Colors.green
                                          : Colors.grey,
                                      fontSize: 35,
                                    ),
                                  ),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "PER ${product?.units ?? ''}",
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 25),
                                        )
                                      ])
                                ],
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    user.favoriteProductIds.contains(product.id)
                                        ? Icons.favorite
                                        : Icons.favorite_outline,
                                    color: user.favoriteProductIds
                                            .contains(product.id)
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    if (user.favoriteProductIds
                                        .contains(product.id)) {
                                      userProvider
                                          .removeFavoriteProduct(product);
                                    } else {
                                      userProvider
                                          .addFavoriteProduct(product);
                                    }
                                    _logClick(product);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: dynamicIconsList.map((iconDetail) {
                                return Column(
                                  children: [
                                    SvgPicture.asset(iconDetail.image),
                                    const SizedBox(height: 5),
                                    Text(iconDetail.head,
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text("Stock remaining: $remainingStock"),
                        const SizedBox(height: 20),
                        Text("In stock: ${inStock ? "Yes" : "No"}"),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Widget to manage quantity
Widget buildQuantityManager(BuildContext context) {
  final productProvider = Provider.of<ProductProvider>(context);
  final userProvider = Provider.of<UserProvider>(context);
  final cartProvider = Provider.of<CartProvider>(context, listen: false);

  final user = userProvider.user;
  final product = productProvider.getProductById(widget.productId);

  // Local state for quantity
  int quantity = cartProvider.items[product?.id]?.quantity ?? 1;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // Quantity Manager Section
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/minus-solid.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                    Color.fromARGB(255, 157, 157, 157), BlendMode.srcIn),
              ),
              onPressed: () {
                setState(() {
                  if (quantity > 1) {
                    quantity--;
                  }
                });
              },
            ),
            // Quantity display window
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                quantity.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/plus-solid.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                    Color.fromARGB(255, 157, 157, 157), BlendMode.srcIn),
              ),
              onPressed: () {
                setState(() {
                  quantity++;
                });
              },
            ),
          ],
        ),
      ),

      // Add to Cart Button Section
      IconButton(
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 40),
        onPressed: () {
          if (product != null) {
            cartProvider.addItem(
              product,
              user,
              selectedVariety,
              quantity, // Using the local quantity state
              notes,
            );
            _logClick(product);
          }
        },
      ),
    ],
  );
}
  void _askForSubscription(Product product) {
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
                final user =
                    Provider.of<UserProvider>(context, listen: false).user;
                final nextDeliveryDate =
                    _calculateNextDeliveryDate(selectedFrequency, selectedDay);
                final subscription = Subscription(
                  product: product,
                  user: user,
                  quantity: quantity, // Adjusted quantity
                  nextDelivery: nextDeliveryDate,
                  frequency: selectedFrequency, // Usnuller-selected frequency
                  price: product.basePrice, variety: selectedVariety!,
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

  Widget buildVarieties(BuildContext context, dynamic product) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Change this number to adjust the number of columns
        childAspectRatio:
            3 / 2, // Adjust the aspect ratio for a 'bento box' feel
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: product.varieties.length,
      itemBuilder: (context, index) {
        final variety = product.varieties[index];
        final isSelected = variety == selectedVariety;

        return GestureDetector(
          onTap: () => _selectVariety(variety),
          child: Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  variety.imageUrl,
                  height: 60, // You can adjust the image size
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 10),
                Text(
                  variety.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on Product {
  get quantity => null;
}

class IconDetail {
  final String image;
  final String head;

  IconDetail({required this.image, required this.head});
}
