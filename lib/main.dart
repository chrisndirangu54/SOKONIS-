// Updated main.dart to support theme switching
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
import 'package:grocerry/screens/profile_screen.dart';
import 'package:grocerry/utils.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart'
    if (dart.library.html) 'uni_links_web.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter/foundation.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

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
  bool _isLightMode = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _initDeepLinking();
    _handleNotification();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLightMode = prefs.getBool('isLightMode') ?? true;
    });
  }

  Future<void> _initDeepLinking() async {
    if (!kIsWeb &&
        (Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.android)) {
      await _initUniLinks();
    }
  }

  Future<void> _initUniLinks() async {
    try {
      final initialLink = await getInitialLink();
      _handleDeepLink(initialLink);
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GroupBuyPage(
              groupBuyId: groupId,
              userLocation: const LatLng(0.0, 0.0),
              user: user,
            ),
          ),
        );
      }
    }
  }

  void _handleNotification() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationAction(message);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
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

  ThemeData _lightTheme() {
    return ThemeData(
      scaffoldBackgroundColor: lightPrimaryColor,
      primaryColor: lightMainColor,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: lightSecondaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightPrimaryColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(color: lightMainColor),
        titleTextStyle: TextStyle(
          color: lightMainColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Comfortaa',
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(
            color: lightTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
            fontFamily: 'Comfortaa'),
        bodyMedium: TextStyle(
            color: lightTextColor3.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'Comfortaa'),
        bodySmall: TextStyle(
            color: lightTextColor2.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            fontFamily: 'Comfortaa'),
        titleLarge: TextStyle(
            color: lightMainColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Comfortaa'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: lightTextColor2),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: lightTextColor)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue)),
        border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey)),
        hintStyle: TextStyle(color: lightTextColor2.withOpacity(0.7)),
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      scaffoldBackgroundColor: primaryColor,
      primaryColor: mainColor,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: secondaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: mainColor),
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
            fontFamily: 'Comfortaa'),
        bodyMedium: TextStyle(
            color: textColor3.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'Comfortaa'),
        bodySmall: TextStyle(
            color: textColor2.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            fontFamily: 'Comfortaa'),
        titleLarge: TextStyle(
            color: mainColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Comfortaa'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: textColor2),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: textColor)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue)),
        border: const OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 44, 44, 44))),
        hintStyle: TextStyle(color: textColor2.withOpacity(0.7)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RestartWidget(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
          ChangeNotifierProvider<ProductProvider>(
              create: (_) => ProductProvider()),
          ChangeNotifierProvider<AuthProvider>(
              create: (context) => AuthProvider(context.read<UserProvider>(),
                  context.read<ProductProvider>())),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => OfferProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: _isLightMode ? ThemeMode.light : ThemeMode.dark,
          home: const LoadingScreen(),
          routes: {
            '/home': (ctx) => const HomeScreen(),
            '/login': (ctx) => const LoginScreen(),
            '/register': (ctx) => const RegisterScreen(),
            '/password-retrieval': (ctx) => const PasswordRetrievalScreen(),
            '/offers': (ctx) => const OffersPage(),
          },
        ),
      ),
    );
  }
}

// Color definitions
Color mainColor = const Color(0XFFF4C750);
Color primaryColor = const Color.fromARGB(255, 39, 39, 39);
Color secondaryColor = const Color.fromARGB(255, 111, 240, 5);
Color textColor = const Color.fromARGB(255, 252, 44, 252);
Color textColor2 = const Color.fromARGB(255, 18, 238, 154);
Color textColor3 = const Color.fromARGB(255, 226, 233, 230);
Color iconBackgroundColor = const Color(0XFF262626);

Color lightMainColor = const Color(0XFFF4C750);
Color lightPrimaryColor = const Color.fromARGB(255, 245, 245, 245);
Color lightSecondaryColor = const Color.fromARGB(255, 76, 175, 80);
Color lightTextColor = const Color.fromARGB(255, 33, 33, 33);
Color lightTextColor2 = const Color.fromARGB(255, 66, 66, 66);
Color lightTextColor3 = const Color.fromARGB(255, 99, 99, 99);
Color lightIconBackgroundColor = const Color.fromARGB(255, 220, 220, 220);
