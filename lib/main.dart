import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/auth_provider.dart';
import 'package:grocerry/screens/group_buy_page.dart';
import 'package:grocerry/screens/order_details_screen.dart';
import 'package:grocerry/screens/product_screen.dart';
import 'package:grocerry/utils.dart';
import 'package:provider/provider.dart';
// Conditional import for uni_links based on platform
import 'package:uni_links/uni_links.dart'
    if (dart.library.html) 'uni_links_web.dart';

import 'package:url_strategy/url_strategy.dart'; // For web deep linking
import 'package:flutter/foundation.dart'; // Needed for kIsWeb check
import 'firebase_options.dart';
import './screens/home_screen.dart';
import './screens/login_screen.dart';
import './screens/register_screen.dart';
import './screens/loading_screen.dart';
import './screens/password_retrieval_screen.dart';
import './screens/offers_page.dart';
import './providers/product_provider.dart';
import './providers/cart_provider.dart';
import './providers/offer_provider.dart';
import './providers/user_provider.dart';
import './providers/order_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle Firebase initialization with error handling and retry logic
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  // Set URL strategy for web to remove '#' from URL
  setPathUrlStrategy();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {

  late User user;
  @override
  void initState() {
    super.initState();
    // Initialize deep linking based on the platform
    _initDeepLinking();
    _handleNotification();

  }

  Future<void> _initDeepLinking() async {
    // Check if the platform is not web (i.e., mobile)
    if (!kIsWeb &&
        (Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.android)) {
      // Mobile platforms (use uni_links)
      await _initUniLinks();
    }
    // Web uses URL strategy with the navigator system (already handled)
  }

  Future<void> _initUniLinks() async {
    // Handle initial link if the app was launched via a deep link
    try {
      final initialLink = await getInitialLink();
      _handleDeepLink(initialLink);

      // Listen for subsequent links
      linkStream.listen((String? link) {
        _handleDeepLink(link);
      });
    } catch (e) {
      print("Error handling deep link: $e");
    }
  }

  void _handleDeepLink(String? link) {
    if (link != null) {
      Uri uri = Uri.parse(link);

      // Handle different paths based on deep link
      if (uri.path == '/register') {
        Navigator.pushNamed(context, '/register');
      } else if (uri.path == '/login') {
        Navigator.pushNamed(context, '/login');
      } else if (uri.path.startsWith('/product/')) {
        String productId = uri.pathSegments[1];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductScreen(productId: productId),
          ),
        );
      } else if (uri.pathSegments.contains('groupbuy')) {
      final groupId = uri.pathSegments.last;
      // Navigate to group buy join page or handle join directly
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupBuyPage(groupBuyId: groupId, userLocation: const LatLng(0.0, 0.0), user: user,),
        ),
      );
    }
    }
  }


  void _handleNotification() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationAction(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationAction(message);
      }
    });
  }

  void _handleNotificationAction(RemoteMessage message) {
    final data = message.data;
    if (data['action'] == 'confirm_payment') {
      final orderId = data['orderId'];
      _openPaymentSelection(orderId);
    }
  }

  void _openPaymentSelection(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentConfirmationScreen(orderId: orderId),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
            create: (_) =>
                UserProvider( )),
        ChangeNotifierProvider<ProductProvider>(
            create: (_) => ProductProvider()),
        ChangeNotifierProvider<AuthProvider>(
            create: (context) => AuthProvider(
                context.read<UserProvider>(), context.read<ProductProvider>())),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => OfferProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: primaryColor,
          primaryColor: mainColor,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: secondaryColor,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: primaryColor,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
            iconTheme: IconThemeData(
              color: mainColor,
            ),
            titleTextStyle: TextStyle(
              color: mainColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Comfortaa',
            ),
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              fontFamily: 'Comfortaa',
            ),
            bodyMedium: TextStyle(
              color: textColor3.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Comfortaa',
            ),
            bodySmall: TextStyle(
              color: textColor2.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              fontFamily: 'Comfortaa',
            ),
            titleLarge: TextStyle(
              color: mainColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Comfortaa',
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: textColor2),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: textColor),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 44, 44, 44)),
            ),
            hintStyle: TextStyle(color: textColor2.withOpacity(0.7)),
          ),
        ),
        home: const LoadingScreen(),
        routes: {
          '/home': (ctx) => const HomeScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/register': (ctx) => const RegisterScreen(),
          '/password-retrieval': (ctx) => const PasswordRetrievalScreen(),
          '/offers': (ctx) => const OffersPage(),
        },
      ),
    );
  }
}
