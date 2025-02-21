import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String openAiApiKey =
      'your_openai_api_key'; // Replace with your API key

  // Function to load data from CSV and upload it to Firestore
  Future<void> addProductsFromCSV(String csvFilePath) async {
    var uuid = const Uuid();

    try {
      // Read CSV file
      final file = File(csvFilePath);
      final csvString = await file.readAsString();
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvString);

      // The first row contains headers
      List<dynamic> headers = csvData[0];

      // Map to store the index of each column based on the header name
      Map<String, int?> headerMap = {
        'id': headers.indexOf('id'),
        'name': headers.indexOf('name'),
        'description': headers.indexOf('description'),
        'category': headers.indexOf('category'),
        'units': headers.indexOf('units'),
        'categoryImageUrl': headers.indexOf('categoryImageUrl'),
        'subcategories': headers.indexOf('subcategories'),
        'subcategoryImageUrls': headers.indexOf('subcategoryImageUrls'),
        'variety': headers.indexOf('variety'),
        'varietyImageUrls': headers.indexOf('varietyImageUrls'),
        'pictureUrl': headers.indexOf('pictureUrl'),
        'basePrice': headers.indexOf('basePrice'),
        'discountedPrice': headers.indexOf('discountedPrice'),
        'isFresh': headers.indexOf('isFresh'),
        'isLocallySourced': headers.indexOf('isLocallySourced'),
        'isOrganic': headers.indexOf('isOrganic'),
        'hasHealthBenefits': headers.indexOf('hasHealthBenefits'),
        'hasDiscounts': headers.indexOf('hasDiscounts'),
        'isEcoFriendly': headers.indexOf('isEcoFriendly'),
        'isSuperfood': headers.indexOf('isSuperfood'),
        'lastPurchaseDate': headers.indexOf('lastPurchaseDate'),
        'isComplementary': headers.indexOf('isComplementary'),
        'complementaryProductIds': headers.indexOf('complementaryProductIds'),
        'isSeasonal': headers.indexOf('isSeasonal'),
        'seasonStart': headers.indexOf('seasonStart'),
        'seasonEnd': headers.indexOf('seasonEnd'),
        'purchaseCount': headers.indexOf('purchaseCount'),
        'recentPurchaseCount': headers.indexOf('recentPurchaseCount'),
        'reviewCount': headers.indexOf('reviewCount'),
        'itemQuantity': headers.indexOf('itemQuantity'),
        'views': headers.indexOf('views'),
        'clicks': headers.indexOf('clicks'),
        'favorites': headers.indexOf('favorites'),
        'timeSpent': headers.indexOf('timeSpent'),
      };

      // Iterate through each product (skip the header row)
      for (int i = 1; i < csvData.length; i++) {
        List<dynamic> row = csvData[i];

        // Safely retrieve data using column indices from headerMap, use default values if column is missing
        String id = uuid.v4(); // Generating a new UUID for each product

        String name = headerMap['name'] != null && headerMap['name'] != -1
            ? row[headerMap['name']!].toString()
            : 'Unnamed Product';

        String description =
            headerMap['description'] != null && headerMap['description'] != -1
                ? row[headerMap['description']!].toString()
                : 'No description available';

        String category =
            headerMap['category'] != null && headerMap['category'] != -1
                ? row[headerMap['category']!].toString()
                : 'Uncategorized';

        String units = headerMap['units'] != null && headerMap['units'] != -1
            ? row[headerMap['units']!].toString()
            : '';

        String categoryImageUrl = headerMap['categoryImageUrl'] != null &&
                headerMap['categoryImageUrl'] != -1
            ? row[headerMap['categoryImageUrl']!].toString()
            : '';

        List<String> subcategories = headerMap['subcategories'] != null &&
                headerMap['subcategories'] != -1
            ? (row[headerMap['subcategories']!].toString().split(','))
            : [];

        List<String> subcategoryImageUrls = headerMap['subcategoryImageUrls'] !=
                    null &&
                headerMap['subcategoryImageUrls'] != -1
            ? (row[headerMap['subcategoryImageUrls']!].toString().split(','))
            : [];

        List<Variety> varieties =
            []; // Assuming varieties are handled separately

        List<String> varietyImageUrls = headerMap['varietyImageUrls'] != null &&
                headerMap['varietyImageUrls'] != -1
            ? (row[headerMap['varietyImageUrls']!].toString().split(','))
            : [];

        String pictureUrl =
            headerMap['pictureUrl'] != null && headerMap['pictureUrl'] != -1
                ? row[headerMap['pictureUrl']!].toString()
                : 'https://example.com/placeholder.jpg';

        double basePrice = headerMap['basePrice'] != null &&
                headerMap['basePrice'] != -1
            ? double.tryParse(row[headerMap['basePrice']!].toString()) ?? 0.0
            : 0.0;

        double discountedPrice = headerMap['discountedPrice'] != null &&
                headerMap['discountedPrice'] != -1
            ? double.tryParse(row[headerMap['discountedPrice']!].toString()) ??
                basePrice
            : basePrice;

        bool isFresh =
            headerMap['isFresh'] != null && headerMap['isFresh'] != -1
                ? row[headerMap['isFresh']!].toString().toLowerCase() == 'true'
                : false;

        bool isLocallySourced = headerMap['isLocallySourced'] != null &&
                headerMap['isLocallySourced'] != -1
            ? row[headerMap['isLocallySourced']!].toString().toLowerCase() ==
                'true'
            : false;

        bool isOrganic = headerMap['isOrganic'] != null &&
                headerMap['isOrganic'] != -1
            ? row[headerMap['isOrganic']!].toString().toLowerCase() == 'true'
            : false;

        bool hasHealthBenefits = headerMap['hasHealthBenefits'] != null &&
                headerMap['hasHealthBenefits'] != -1
            ? row[headerMap['hasHealthBenefits']!].toString().toLowerCase() ==
                'true'
            : false;

        bool hasDiscounts = headerMap['hasDiscounts'] != null &&
                headerMap['hasDiscounts'] != -1
            ? row[headerMap['hasDiscounts']!].toString().toLowerCase() == 'true'
            : false;

        bool isEcoFriendly = headerMap['isEcoFriendly'] != null &&
                headerMap['isEcoFriendly'] != -1
            ? row[headerMap['isEcoFriendly']!].toString().toLowerCase() ==
                'true'
            : false;

        bool isSuperfood = headerMap['isSuperfood'] != null &&
                headerMap['isSuperfood'] != -1
            ? row[headerMap['isSuperfood']!].toString().toLowerCase() == 'true'
            : false;

        DateTime? lastPurchaseDate = headerMap['lastPurchaseDate'] != null &&
                headerMap['lastPurchaseDate'] != -1
            ? DateTime.tryParse(row[headerMap['lastPurchaseDate']!].toString())
            : null;

        bool isComplementary = headerMap['isComplementary'] != null &&
                headerMap['isComplementary'] != -1
            ? row[headerMap['isComplementary']!].toString().toLowerCase() ==
                'true'
            : false;

        List<String> complementaryProductIds =
            headerMap['complementaryProductIds'] != null &&
                    headerMap['complementaryProductIds'] != -1
                ? row[headerMap['complementaryProductIds']!]
                    .toString()
                    .split(',')
                : [];

        bool isSeasonal = headerMap['isSeasonal'] != null &&
                headerMap['isSeasonal'] != -1
            ? row[headerMap['isSeasonal']!].toString().toLowerCase() == 'true'
            : false;

        DateTime? seasonStart =
            headerMap['seasonStart'] != null && headerMap['seasonStart'] != -1
                ? DateTime.tryParse(row[headerMap['seasonStart']!].toString())
                : null;

        DateTime? seasonEnd =
            headerMap['seasonEnd'] != null && headerMap['seasonEnd'] != -1
                ? DateTime.tryParse(row[headerMap['seasonEnd']!].toString())
                : null;

        int purchaseCount = headerMap['purchaseCount'] != null &&
                headerMap['purchaseCount'] != -1
            ? int.tryParse(row[headerMap['purchaseCount']!].toString()) ?? 0
            : 0;

        int recentPurchaseCount = headerMap['recentPurchaseCount'] != null &&
                headerMap['recentPurchaseCount'] != -1
            ? int.tryParse(row[headerMap['recentPurchaseCount']!].toString()) ??
                0
            : 0;

        int reviewCount =
            headerMap['reviewCount'] != null && headerMap['reviewCount'] != -1
                ? int.tryParse(row[headerMap['reviewCount']!].toString()) ?? 0
                : 0;

        int itemQuantity =
            headerMap['itemQuantity'] != null && headerMap['itemQuantity'] != -1
                ? int.tryParse(row[headerMap['itemQuantity']!].toString()) ?? 0
                : 0;

        int views = headerMap['views'] != null && headerMap['views'] != -1
            ? int.tryParse(row[headerMap['views']!].toString()) ?? 0
            : 0;

        int clicks = headerMap['clicks'] != null && headerMap['clicks'] != -1
            ? int.tryParse(row[headerMap['clicks']!].toString()) ?? 0
            : 0;

        int favorites =
            headerMap['favorites'] != null && headerMap['favorites'] != -1
                ? int.tryParse(row[headerMap['favorites']!].toString()) ?? 0
                : 0;

        int timeSpent =
            headerMap['timeSpent'] != null && headerMap['timeSpent'] != -1
                ? int.tryParse(row[headerMap['timeSpent']!].toString()) ?? 0
                : 0;

        // Create Product object
        Product product = Product(
          id: id,
          name: name,
          basePrice: basePrice,
          description: description,
          category: category,
          units: units,
          categoryImageUrl: categoryImageUrl,
          subcategories: subcategories,
          subcategoryImageUrls: subcategoryImageUrls,
          varieties: varieties,
          varietyImageUrls: varietyImageUrls,
          pictureUrl: pictureUrl,
          isFresh: isFresh,
          isLocallySourced: isLocallySourced,
          isOrganic: isOrganic,
          hasHealthBenefits: hasHealthBenefits,
          hasDiscounts: hasDiscounts,
          discountedPrice: discountedPrice,
          isEcoFriendly: isEcoFriendly,
          isSuperfood: isSuperfood,
          lastPurchaseDate: lastPurchaseDate,
          isComplementary: isComplementary,
          complementaryProductIds: complementaryProductIds,
          isSeasonal: isSeasonal,
          seasonStart: seasonStart,
          seasonEnd: seasonEnd,
          purchaseCount: purchaseCount,
          recentPurchaseCount: recentPurchaseCount,
          reviewCount: reviewCount,
          itemQuantity: itemQuantity,
          views: views,
          clicks: clicks,
          favorites: favorites,
          timeSpent: timeSpent,
        );

        // If variety column exists, use it, otherwise ask ChatGPT
        if (headerMap['variety'] != null && headerMap['variety'] != -1) {
          varieties = _getVarietiesFromRow(row[headerMap['variety']!]);
        } else {
          varieties = await determineVarietiesUsingChatGPT(name);
        }

        // Upload the product to Firestore
        await _firestore
            .collection('products')
            .doc(product.id)
            .set(product.toMap());
      }

      print('${csvData.length - 1} products added successfully from CSV!');
    } catch (e) {
      print('Error reading CSV file: $e');
    }
  }

  // Helper method to parse varieties from a row
  List<Variety> _getVarietiesFromRow(String rowData) {
    return rowData
        .split(',')
        .map((variety) => Variety(
            name: variety, color: '', size: '', imageUrl: '', price: 0.0))
        .toList();
  }

  // Function to determine varieties using ChatGPT
  Future<List<Variety>> determineVarietiesUsingChatGPT(
      String productName) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an AI expert in product classification and variety determination.',
        },
        {
          'role': 'user',
          'content':
              'Determine varieties for the product: $productName based on weight, color, size, or other differences.',
        }
      ],
      'max_tokens': 100,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final varietiesText = data['choices'][0]['message']['content'];
        return _parseVarietiesFromText(varietiesText);
      } else {
        print('Failed to determine varieties: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error during API request: $e');
      return [];
    }
  }

  // Helper function to parse varieties from ChatGPT response
  List<Variety> _parseVarietiesFromText(String text) {
    List<String> varietyNames =
        text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    return varietyNames
        .map((name) =>
            Variety(name: name, color: '', size: '', price: 0.0, imageUrl: ''))
        .toList();
  }
}
Future<Product> determineProductUsingAI(
    String productName,
    Map<String, dynamic> productData,
  ) async {
    // URL for Grok API (this would need to be correct based on your setup)
    final url = Uri.parse('https://api.x.ai/v1/chat/completions'); // Replace with actual Grok API endpoint

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $grokApiKey', // Replace 'grokApiKey' with your actual API key variable
    };

    String query =
        'Product: $productName. Data: ${jsonEncode(productData)}. Please organize this into a Product object with the following structure. If product is repeated, convert it into a variety:\n\n'
        '- **Name**: [String]\n'
        '- **Base Price**: [double]\n'
        '- **Description**: [String]\n'
        '- **Category**: [String]\n'
        '- **Units**: [String]\n'
        '- **Category Image URL**: [String]\n'
        '- **Subcategories**: [List<String>]\n'
        '- **Subcategory Image URLs**: [List<String>]\n'
        '- **Varieties**: [List<Variety>]\n'
        '  - **Name**: [String]\n'
        '  - **Color**: [String]\n'
        '  - **Size**: [String]\n'
        '  - **Image URL**: [String]\n'
        '  - **Price**: [double]\n'
        '  - **Discounted Price**: [double?]\n'
        '- **Picture URL**: [String]\n'
        '- **Is Fresh**: [bool]\n'
        '- **Is Locally Sourced**: [bool]\n'
        '- **Is Organic**: [bool]\n'
        '- **Has Health Benefits**: [bool]\n'
        '- **Has Discounts**: [bool]\n'
        '- **Discounted Price**: [double]\n'
        '- **Is Eco-Friendly**: [bool]\n'
        '- **Is Superfood**: [bool]\n'
        '- **Consumption Time**: [List<String>] // Possible values: lunch, breakfast, supper\n'
        '- **Weather**: [List<String>] // Possible values: rainy, cloudy, sunny, other\n'
        '- **Min Price**: [double?]\n\n'
        'Respond in JSON format matching this structure.';

    final body = jsonEncode({
      'model': 'grok-beta', // Specify the Grok model you want to use
      'messages': [
        {
          'role': 'system',
          'content': 'You are an AI expert in product data organization.',
        },
        {
          'role': 'user',
          'content': query,
        }
      ],
      'max_tokens': 1000,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String jsonContent = data['choices'][0]['message']['content'];

      Map<String, dynamic> productMap = jsonDecode(jsonContent);

      // Assuming fromJson now returns Future<List<Product>>
      List<Product> products = await Product.fromJson(productMap);
      if (products.isNotEmpty) {
        Product product = products[0];

        // Update the discounted price stream with the first product's discounted price
        groupBuyService!.updateDiscountedPrice(product.discountedPrice);

        // Here, we might need to adjust the product's consumption time and weather
        // based on your UI selections, assuming they are stored in controllers
        if (_consumptionTimeController != null && _weatherController != null) {
          product.consumptionTime = _consumptionTimeController.text.split(', ');
          product.weather = _weatherController.text.split(', ');
        }

        return product;
      } else {
        throw Exception('No product data was returned');
      }
    } else {
      print('Failed to determine product details: ${response.body}');
      throw Exception('Failed to fetch product details from AI');
    }
  }