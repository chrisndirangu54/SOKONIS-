import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/offer.dart'; // For uploading the image
import 'package:tuple/tuple.dart'; // Add tuple package for tuple support

class OfferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Flags to control the state of offers
  bool _weekendOffersEnabled = true;
  bool _holidayOffersEnabled = true;

  OfferService() {
    // Initialize notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _notificationsPlugin.initialize(initializationSettings);
  }

  // Methods to check if offers are enabled
  bool isWeekendOffersEnabled() => _weekendOffersEnabled;
  bool isHolidayOffersEnabled() => _holidayOffersEnabled;

  // Methods to enable or disable offers
  void enableWeekendOffers() {
    _weekendOffersEnabled = true;
  }

  void disableWeekendOffers() {
    _weekendOffersEnabled = false;
  }

  void enableHolidayOffers() {
    _holidayOffersEnabled = true;
  }

  void disableHolidayOffers() {
    _holidayOffersEnabled = false;
  }

  Future<void> createOffers() async {
    final DateTime now = DateTime.now();
    final Tuple2<bool, String?> holidayInfo = _checkIfPublicHoliday(now);
    final bool isPublicHoliday = holidayInfo.item1;
    final String? holidayName = holidayInfo.item2;
    final bool isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    if ((isPublicHoliday && _holidayOffersEnabled) ||
        (isWeekend && _weekendOffersEnabled)) {
      double discount = isPublicHoliday ? 0.10 : 0.05;
      String offerTitle = isPublicHoliday
          ? "Public Holiday Special - 35% Off!"
          : "Weekend Deal - 5% Off!";

      // Adjust prices for public holidays to appear as 35% off
      final QuerySnapshot productsSnapshot =
          await _firestore.collection('products').get();
      for (QueryDocumentSnapshot productDoc in productsSnapshot.docs) {
        final productData = productDoc.data() as Map<String, dynamic>;
        double originalPrice = productData['price'];
        double offer = isPublicHoliday
            ? _calculateAdjustedPrice(originalPrice, 0.35)
            : originalPrice * (1 - discount);

        String newImageUrl = await _embedDiscountOnImage(
          productData['imageUrl'],
          isPublicHoliday ? 35 : 5,
          productData['name'],
        );

        // Create and save offer
        Offer currentOffer = Offer(
          id: productDoc.id,
          title: offerTitle,
          description:
              'Get ${isPublicHoliday ? 35 : 5}% off on ${productData['name']}!',
          imageUrl: newImageUrl,
          startDate: now,
          endDate: now.add(const Duration(days: 1)), // 1-day offer
          price: originalPrice, // Use adjustedPrice here if needed
          productId: '',
          discountedPrice: offer,
        );

        await _firestore
            .collection('offers')
            .doc(currentOffer.id)
            .set(currentOffer.toMap());
      }

      _notifyUsers(offerTitle, holidayName);
    }
  }

  double _calculateAdjustedPrice(double price, double displayDiscount) {
    double adjustedDiscount = 0.1; // 10% discount but display as 35%
    return price * (1 - adjustedDiscount);
  }

  Future<img.BitmapFont> loadFont() async {
    // Load the .fnt file as a string
    final String fontData =
        await rootBundle.loadString('assets/comfortaa-regular.fnt');

    // Load the .png file associated with the .fnt
    final ByteData fontImageData =
        await rootBundle.load('assets/comfortaa-regular.fnt');
    final Uint8List fontImageBytes = fontImageData.buffer.asUint8List();

    // Decode the image
    final img.Image fontImage = img.decodeImage(fontImageBytes)!;

    // Create the BitmapFont using the .fnt and associated image
    final img.BitmapFont font = img.BitmapFont.fromFnt(fontData, fontImage);

    return font;
  }

  Future<String> _embedDiscountOnImage(
      String imageUrl, int discount, String productName) async {
    try {
      // Load the font
      img.BitmapFont font = await loadFont();

      // Step 1: Download the image from the given URL
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image');
      }

      // Step 2: Decode the image into an Image object
      Uint8List imageData = response.bodyBytes;
      img.Image image = img.decodeImage(imageData)!;

      // Step 3: Add the discount percentage text
      image = img.drawString(
        image, // The image object
        font, // The BitmapFont loaded earlier
        10, // X position
        10, // Y position
        '$discount% OFF', // Text to draw
        color: img.getColor(255, 0, 0), // Color for the text
      );

      // Step 4: Add the product name text
      image = img.drawString(
        image, // The image object
        font, // The BitmapFont loaded earlier
        10, // X position
        image.height - 30, // Y position
        productName, // Text to draw
        color: img.getColor(255, 255, 255), // Color for the text
      );

      // Step 5: Encode the image back to PNG
      Uint8List pngBytes = Uint8List.fromList(img.encodePng(image));

      // Step 6: Upload the image to Firebase Storage
      FirebaseStorage storage = FirebaseStorage.instance;
      String filePath = 'offers/${DateTime.now().millisecondsSinceEpoch}.png';
      Reference ref = storage.ref().child(filePath);
      UploadTask uploadTask = ref.putData(pngBytes);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});

      // Step 7: Get the download URL of the uploaded image
      String newImageUrl = await snapshot.ref.getDownloadURL();

      return newImageUrl;
    } catch (e) {
      print('Error embedding discount on image: $e');
      rethrow;
    }
  }

  Future<void> _notifyUsers(String offerTitle, String? holidayName) async {
    final QuerySnapshot usersSnapshot =
        await _firestore.collection('users').get();

    for (QueryDocumentSnapshot userDoc in usersSnapshot.docs) {
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      String userName = userData['name'];

      String notificationMessage =
          await _generateNotificationMessage(userName, holidayName);

      // Send notification
      await _notificationsPlugin.show(
        0, // ID for the notification
        offerTitle, // Title of the notification
        notificationMessage, // Body of the notification
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'offer_channel', // Channel ID
            'Offers', // Channel name
            channelDescription:
                'Channel for offer notifications', // Channel description
          ),
        ),
      );
    }
  }

  Future<String> _generateNotificationMessage(
      String userName, String? holidayName) async {
    try {
      // Define the prompt with the user's name and holiday name for a personalized message
      String prompt =
          "Generate a creative offer notification message for a user named $userName, mentioning the holiday '$holidayName'.";

      // Call ChatGPT API to generate the message
      final response = await http.post(
        Uri.parse(
            'https://api.openai.com/v1/engines/davinci-codex/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_OPENAI_API_KEY',
        },
        body: json.encode({
          'prompt': prompt,
          'max_tokens': 50,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['choices'][0]['text'].trim();
      } else {
        print(
            'Failed to generate message. Status code: ${response.statusCode}');
        return _getFallbackMessage(userName, holidayName);
      }
    } catch (e) {
      print('Error generating message: $e');
      return _getFallbackMessage(userName, holidayName);
    }
  }

  String _getFallbackMessage(String userName, String? holidayName) {
    List<String> messages = [
      "Hey $userName, don't miss out on our exclusive offer for $holidayName!",
      "Special $holidayName deal just for you, $userName!",
      "Hurry, $userName, limited time $holidayName offer available now!",
    ];
    messages.shuffle();
    return messages.first;
  }

  Tuple2<bool, String?> _checkIfPublicHoliday(DateTime date) {
    Map<DateTime, String> publicHolidays = {
      DateTime(date.year, 1, 1): "New Year's Day",
      DateTime(date.year, 5, 1): "Labour Day",
      DateTime(date.year, 6, 1): "Madaraka Day",
      DateTime(date.year, 10, 20): "Mashujaa Day",
      DateTime(date.year, 12, 12): "Jamhuri Day",
      DateTime(date.year, 12, 25): "Christmas Day",
      DateTime(date.year, 12, 26): "Boxing Day",
    };

    // Add Easter
    DateTime easter = calculateEaster(date.year);
    publicHolidays[easter] = "Easter Sunday";

    for (DateTime holiday in publicHolidays.keys) {
      if (date.year == holiday.year &&
          date.month == holiday.month &&
          date.day == holiday.day) {
        return Tuple2(true, publicHolidays[holiday]);
      }
    }
    return const Tuple2(false, null);
  }

  DateTime calculateEaster(int year) {
    // Calculation for Easter Sunday for a given year
    int a = year % 19;
    int b = (year / 100).floor();
    int c = year % 100;
    int d = (b / 4).floor();
    int e = b % 4;
    int f = ((b + 8) / 25).floor();
    int g = ((b - f + 1) / 3).floor();
    int h = (19 * a + b - d - g + 15) % 30;
    int i = (c / 4).floor();
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = ((a + 11 * h + 22 * l) / 451).floor();
    int month = ((h + l - 7 * m + 114) / 31).floor();
    int day = ((h + l - 7 * m + 114) % 31) + 1;

    return DateTime(year, month, day);
  }
}
