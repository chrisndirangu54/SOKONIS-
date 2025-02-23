import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:grocerry/models/offer.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/screens/product_screen.dart';
import 'package:grocerry/services/notification_service.dart';
import 'package:grocerry/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:grocerry/providers/cart_provider.dart'; // For cart functionality

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  late String selectedVariety; // Initialized in initState
  late User user; // Initialized in initState
  late CartProvider cartProvider;
  final List<Product> _genomicAlternatives = [];
  DateTime? _viewStartTime;
Offer? offer;
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  List<String> _firestoreProductNames = [];
  bool _isLoading = false;
  Product? _matchedProduct; // To store the matched product for display
  Product? product;
  double? discountedPrice;
  Stream<Map<String, double?>?>? discountedPriceStream;
  Stream<double?>? discountedPriceStream2;
  late StreamSubscription<double?>? _discountedPriceSubscription;
  @override
  void initState() {
    super.initState();
    cartProvider = Provider.of<CartProvider>(context, listen: false);
    user = Provider.of<UserProvider>(context, listen: false).user; // Assuming UserProvider exists
    selectedVariety = "Default Variety"; // Default value for selectedVariety
    _fetchAllProductNames();
    // Check if widget.product is not null before accessing its properties
    if (product != null) {
      _discountedPriceSubscription =
          product!.discountedPriceStream2?.listen(
        (price) {
          setState(() {
            discountedPriceStream2 = price as Stream<double?>?;
          });
        },
      );
  _scrollController = ScrollController();

      // Check if product has varieties before iterating
      for (var variety in product!.varieties) {
        if (variety.discountedPriceStream != null) {
          _listenToDiscountedPriceStream2(variety.discountedPriceStream!);
        }
      }
        } else {
      print("Product is null in HomeScreen initState");
    }

  }



@override
void dispose() {
  _scrollController.dispose();
  _controller.dispose();
  _discountedPriceSubscription?.cancel();
  _logTimeSpent(product, _viewStartTime);
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
  Future<void> _fetchAllProductNames() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('products').get();

    setState(() {
      _firestoreProductNames = snapshot.docs.map((doc) => doc['name'] as String).toList();
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

  void _logClick(Product? product, String action) {
    FirebaseFirestore.instance.collection('user_logs').add({
      'event': 'click',
      'productId': product!.id,
      'userId': Provider.of<UserProvider>(context, listen: false).user.id,
      'action': '',
      'timestamp': DateTime.now(),
    });
  }

  
  Widget buildProductCard(Product? product, {required bool isGrid}) {
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
        _logClick(product, 'Product_Screen');
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
          product!, user, selectedVariety, initialQuantity, notes ?? '');
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
                                ...product!.genomicAlternatives.map((alternative) {
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
                product, 'Product_Screen'
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

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add("You: $message");
      _conversationHistory.add({"role": "user", "content": message});
    });

    setState(() {
      _isLoading = true;
    });

    double sentimentScore = await _getSentimentScore(message);
    _storeConversationToFirestore(message, sentimentScore, "user");

    var response = await _processMessageWithChatGPT(_conversationHistory);
    setState(() {
      _messages.add("Bellamy: $response");
      _isLoading = false;
    });

    sentimentScore = await _getSentimentScore(response);
    _storeConversationToFirestore(response, sentimentScore, "bot");
  }

  final List<Map<String, String>> _conversationHistory = [];
  
  late ScrollController _scrollController;
  
  late bool _isFlipped;

  Future<void> _storeConversationToFirestore(String message, double sentimentScore, String sender) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('conversations').add({
      'message': message,
      'sentimentScore': sentimentScore,
      'sender': sender,
      'timestamp': Timestamp.now(),
      'userId': user.id,
    });
  }

  Future<double> _getSentimentScore(String text) async {
    const String apiKey = "YOUR_GOOGLE_CLOUD_API_KEY";
    final response = await http.post(
      Uri.parse('https://language.googleapis.com/v1/documents:analyzeSentiment?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "document": {"type": "PLAIN_TEXT", "content": text},
        "encodingType": "UTF8"
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['documentSentiment']['score'];
    } else {
      return 0.0;
    }
  }

  Future<String> _processMessageWithChatGPT(List<Map<String, String>> conversationHistory) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": conversationHistory,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String chatbotResponse = data['choices'][0]['message']['content'];

      if (chatbotResponse.contains('Sorry') || chatbotResponse.length < 10) {
        setState(() {
          _messages.add("Bellamy: I'm having trouble answering that question. Let me redirect you to the Technical Support Team.");
        });
        _openWhatsApp();
        return "Redirecting you to the Technical Support Team...";
      } else {
        return chatbotResponse;
      }
    } else {
      return "I'm unable to process your request at the moment. Let me redirect you to Technical Support Team for help.";
    }
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

  Future<void> _processImageWithOCR(String imagePath) async {
    var extractedText = await _performOCR(imagePath);
    await _sendMessage(extractedText!);

    var recognizedProducts = await _recognizeProducts(imagePath);
    for (var product in recognizedProducts) {
      await _processProduct(product, selectedVariety, 1); // Default quantity
    }
  }

  Future<String?> _performOCR(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.isNotEmpty ? recognizedText.text : "No text found.";
    } catch (e) {
      print("Error performing OCR: $e");
      return "Error extracting text from image.";
    } finally {
      textRecognizer.close();
    }
  }

  Future<List<String>> _recognizeProducts(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    final objectDetector = ObjectDetector(options: options);

    try {
      final List<DetectedObject> detectedObjects = await objectDetector.processImage(inputImage);
      List<String> recognizedProducts = [];
      for (DetectedObject detectedObject in detectedObjects) {
        for (Label label in detectedObject.labels) {
          recognizedProducts.add(label.text);
        }
      }
      return recognizedProducts.isNotEmpty ? recognizedProducts : ["No products recognized."];
    } catch (e) {
      print("Error performing object recognition: $e");
      return ["Error recognizing products."];
    } finally {
      objectDetector.close();
    }
  }

  Future<void> _processProduct(String product, String selectedVariety, dynamic quantity) async {
    String? englishProductName = await _convertToEnglish(product);
    if (englishProductName != null) {
      var match = await _compareWithFirestore(englishProductName);
      if (match != null) {
        setState(() {
          _matchedProduct = match; // Store for display
        });

        await _sendMessage("Found $match to display.");
        Fluttertoast.showToast(
          msg: "$match found.",
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        await _sendMessage("No matching product found for: $product");
      }
    } else {
      await _sendMessage("Could not convert product name to English.");
    }
  }

  Future<String?> _convertToEnglish(String productName) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": "Translate the product name '$productName' to English."}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return null;
    }
  }

  Future<Product?> _compareWithFirestore(String productName) async {
    final suggestions = await _getSuggestionsFromChatGPT(productName);

    if (suggestions != null && suggestions.isNotEmpty) {
      for (String suggestion in suggestions) {
        final matchedProduct = _firestoreProductNames.firstWhere(
          (name) => _isProductMatch(name, suggestion),
          orElse: () => '',
        );
        if (matchedProduct.isNotEmpty) {
          // Fetch full Product object from Firestore
          final snapshot = await FirebaseFirestore.instance
              .collection('products')
              .where('name', isEqualTo: matchedProduct)
              .limit(1)
              .get();
          if (snapshot.docs.isNotEmpty) {
            return Product.fromMap(snapshot.docs.first.data()); // Assuming Product.fromMap exists
          }
        }
      }
    }
    return null;
  }

  Future<List<String>?> _getSuggestionsFromChatGPT(String productName) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content": "What are some similar product names or possible corrections for the name '$productName'? Include synonyms and common typos."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['choices'][0]['message']['content'] as String).split(',').map((s) => s.trim()).toList();
    } else {
      print("Error fetching suggestions from ChatGPT: ${response.body}");
      return null;
    }
  }

bool _isProductMatch(String firestoreProductName, String userInput) {
  final fuzzy = Fuzzy([firestoreProductName]);
  final result = fuzzy.search(userInput);
  return result.isNotEmpty && result.first.score > 0.7; // Adjust threshold as needed
}

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      await _processImageWithOCR(pickedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot - Bellamy"),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _pickImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUserMessage = message.startsWith("You:");
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUserMessage ? Colors.blue[200] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(color: isUserMessage ? Colors.white : Colors.black),
                  ),
                );
              },
            ),
          ),
          if (_matchedProduct != null) // Display matched product card
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: buildProductCard(_matchedProduct!, isGrid: false),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_controller.text);
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
