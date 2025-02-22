import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grocerry/models/offer.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/subscription_model.dart';
import 'package:grocerry/services/notification_service.dart';
import 'package:grocerry/services/subscription_service.dart';
import 'package:grocerry/utils.dart';
import 'package:provider/provider.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart'; // For adding/removing favorites
import 'package:grocerry/providers/cart_provider.dart'; // For cart functionality
import 'package:shimmer/shimmer.dart';
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
  final StreamController<List<Product>> _predictedProductsController =
      StreamController<List<Product>>.broadcast();
  ProductScreenState();
  DateTime? _viewStartTime;
  Variety? selectedVariety; // Track the selected variety
  late AnimationController _controller;
  late ScrollController _scrollController;
  late Subscription subscription;
  late SubscriptionService subscriptionService = SubscriptionService();
  Product? product;
  double? discountedPrice;
  Stream<Map<String, double?>?>? discountedPriceStream;
  Stream<double?>? discountedPriceStream2;
  late StreamSubscription<double?>? _discountedPriceSubscription;
  late final Animation<double> _scaleAnimation =
      Tween<double>(begin: 2.3, end: 2.7).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),
  );
  final List<Product> _genomicAlternatives = [];
  Stream<List<Product>> get predictedProductsStream =>
      _predictedProductsController.stream;
  late final Animation<double> _rotationAnimation = Tween<double>(
          begin: 0, end: 3.14) // 3.14 radians for 180 degrees
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  // Control the state of the selected variety and image index
  int selectedVarietyIndex = 0; // Changed variable name
  int currentImageIndex = 0;
  Offer? offer;

  var notes;
  
  late bool _isFlipped;

  get quantity => null;

  @override
  void initState() {
    super.initState();
    // Initialize the ScrollController
    _scrollController = ScrollController();
   _loadPredictedProducts(); // Load initial data on initialization

    // Initialize the AnimationController
    // Initialize the AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Adjust the duration as needed
    );
    // Fetch product and set default selected variety
    _logProductView(product);
    _viewStartTime = DateTime.now();
    _fetchProductAnalytics();
    
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
      for (var variety in widget.product!.varieties) {
        if (variety.discountedPriceStream != null) {
          _listenToDiscountedPriceStream2(variety.discountedPriceStream!);
        }
      }
        } else {
      print("Product is null in HomeScreen initState");
    }

  }

  void _selectVariety(Variety variety) {
    setState(() {
      selectedVariety = variety;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
      _predictedProductsController.close();

    _logTimeSpent(product, _viewStartTime);
    _controller.dispose();
    super.dispose();
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

  Future<void> _loadPredictedProducts() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Mock delay
      final List<Product> predictedProducts = [
      ];
      _predictedProductsController.add(predictedProducts);
    } catch (e) {
      _predictedProductsController.addError(e);
    }
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

  void _logClick(Product? product) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'click',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
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
  Widget _buildProductCard(Product? product, {required bool isGrid}) {
    final productImageUrl = product!.pictureUrl.isNotEmpty
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
  
    // Check if the product is in stock
    final productProvider = Provider.of<ProductProvider>(context);
    bool inStock = productProvider.isInStock(product);
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
          transform: _isFlipped
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
          product!, Provider.of<UserProvider>(context, listen: false).user, selectedVariety, initialQuantity, notes ?? '');
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
                                    Container(
                                      width: 25,
                                      height: 25,
                                      margin:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          variety.imageUrl,
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
                                                    ? ' \$${selectedVariety!.discountedPriceStream?.toStringAsFixed(2) ?? 'N/A'}'
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
    num averageRating = 0;
    if (product.reviews != null && product.reviews!.isNotEmpty) {
      averageRating = product.reviews!
              .map((review) => review.rating)
              .reduce((a, b) => a + b) /
          product.reviews!.length;
    }

    // Ensure the variety is initialized
    if (selectedVariety == null && product.varieties.isNotEmpty) {
      selectedVariety = product.varieties.first;
    }

    const int highlyRatedThreshold = 100;
    final int remainingStock = productProvider.getRemainingStock(product);
    final bool inStock = productProvider.isInStock(product);

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
                  child: Row(
  children: [
    // Star rating
    ...List.generate(
      5,
      (starIndex) => Icon(
        Icons.star,
        color: starIndex < (averageRating ?? 0) // Use null-safe default
            ? Colors.orange
            : Colors.grey,
      ),
    ),
    // Review count text
    Text(
      " (${product.reviewCount} reviews)",
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      maxLines: 1, // Named argument
      overflow: TextOverflow.ellipsis,
    ),
  ],
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
                                    selectedVariety!.discountedPriceStream !=
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
                                    '\$${selectedVariety!.discountedPriceStream!.toStringAsFixed(2)}',
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
                                    '\$${product.discountedPriceStream2?.toStringAsFixed(2)}',
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
                                          "PER ${product.units ?? ''}",
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
                                    if (iconDetail.image != null)
                                      SvgPicture.asset(iconDetail.image!),
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
              const SizedBox(height: 20),
                                        StreamBuilder<List<Product>>(
        stream: predictedProductsStream, // Use the stream
        builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                              } else {
                                final recommendedProducts = snapshot.data ?? [];
                                if (recommendedProducts.isEmpty) {
                                  return const Text('No recommended products available.', style: TextStyle(color: Colors.grey));
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recommended Products',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 200,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: recommendedProducts.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: SizedBox(
                                              width: 150,
                                              child: _buildProductCard(recommendedProducts[index], isGrid: false),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
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

extension on Stream<Map<String, double?>?> {
  toStringAsFixed(int i) {}
}

extension on Stream<double?>? {
  toStringAsFixed(int i) {}
}

extension on Product {
  get quantity => null;
}


class IconDetail {
  IconDetail({this.image, required this.head, this.icon});

  final String head;
  final String? image;
  final Icon? icon;
}
