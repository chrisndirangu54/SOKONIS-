import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/services/groupbuy_service.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';

class ProductService {
  late final GroupBuyService? groupBuyService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String openAiApiKey = 'your_openai_api_key'; // Replace with your API key

  ProductService({this.groupBuyService});

  // Function to load data from CSV and upload it to Firestore
  Future<void> addProductsFromCSV(String csvFilePath) async {
    var uuid = const Uuid();

    try {
      // Read CSV file
      final file = File(csvFilePath);
      final csvString = await file.readAsString();
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      // The first row contains headers
      List<dynamic> headers = csvData[0];

      // Map to store the index of each column based on the header name
      Map<String, int?> headerMap = {
        'id': headers.indexOf('id'),
        'name': headers.indexOf('name'),
        'description': headers.indexOf('description'),
        'categories': headers.indexOf('categories'), // Updated to handle multiple categories
        'units': headers.indexOf('units'),
        'tags': headers.indexOf('tags'),
        'varieties': headers.indexOf('varieties'),
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
        'consumptionTime': headers.indexOf('consumptionTime'),
        'weather': headers.indexOf('weather'),
        'rating': headers.indexOf('rating'),
        'userViews': headers.indexOf('userViews'), // New field
        'userTimeSpent': headers.indexOf('userTimeSpent'), // New field
        'categoryImageUrls': headers.indexOf('categoryImageUrls'), // To match List<Category>
        'subcategoryNames': headers.indexOf('subcategoryNames'), // For subcategories
        'subcategoryImageUrls': headers.indexOf('subcategoryImageUrls'), // For subcategories
      };

      // Iterate through each product (skip the header row)
      for (int i = 1; i < csvData.length; i++) {
        List<dynamic> row = csvData[i];

        // Safely retrieve data using column indices from headerMap, use default values if column is missing
        String id = headerMap['id'] != null && headerMap['id'] != -1
            ? row[headerMap['id']!].toString()
            : uuid.v4();
        String name = headerMap['name'] != null && headerMap['name'] != -1
            ? row[headerMap['name']!].toString()
            : 'Unnamed Product';
        String description = headerMap['description'] != null && headerMap['description'] != -1
            ? row[headerMap['description']!].toString()
            : 'No description available';
        String units = headerMap['units'] != null && headerMap['units'] != -1
            ? row[headerMap['units']!].toString()
            : '';
        List<String> tags = headerMap['tags'] != null && headerMap['tags'] != -1
            ? row[headerMap['tags']!].toString().split(',')
            : [];
        String pictureUrl = headerMap['pictureUrl'] != null && headerMap['pictureUrl'] != -1
            ? row[headerMap['pictureUrl']!].toString()
            : 'https://example.com/placeholder.jpg';
        double basePrice = headerMap['basePrice'] != null && headerMap['basePrice'] != -1
            ? double.tryParse(row[headerMap['basePrice']!].toString()) ?? 0.0
            : 0.0;
        double discountedPrice = headerMap['discountedPrice'] != null && headerMap['discountedPrice'] != -1
            ? double.tryParse(row[headerMap['discountedPrice']!].toString()) ?? basePrice
            : basePrice;
        bool isFresh = headerMap['isFresh'] != null && headerMap['isFresh'] != -1
            ? row[headerMap['isFresh']!].toString().toLowerCase() == 'true'
            : false;
        bool isLocallySourced = headerMap['isLocallySourced'] != null && headerMap['isLocallySourced'] != -1
            ? row[headerMap['isLocallySourced']!].toString().toLowerCase() == 'true'
            : false;
        bool isOrganic = headerMap['isOrganic'] != null && headerMap['isOrganic'] != -1
            ? row[headerMap['isOrganic']!].toString().toLowerCase() == 'true'
            : false;
        bool hasHealthBenefits = headerMap['hasHealthBenefits'] != null && headerMap['hasHealthBenefits'] != -1
            ? row[headerMap['hasHealthBenefits']!].toString().toLowerCase() == 'true'
            : false;
        bool hasDiscounts = headerMap['hasDiscounts'] != null && headerMap['hasDiscounts'] != -1
            ? row[headerMap['hasDiscounts']!].toString().toLowerCase() == 'true'
            : false;
        bool isEcoFriendly = headerMap['isEcoFriendly'] != null && headerMap['isEcoFriendly'] != -1
            ? row[headerMap['isEcoFriendly']!].toString().toLowerCase() == 'true'
            : false;
        bool isSuperfood = headerMap['isSuperfood'] != null && headerMap['isSuperfood'] != -1
            ? row[headerMap['isSuperfood']!].toString().toLowerCase() == 'true'
            : false;
        DateTime? lastPurchaseDate = headerMap['lastPurchaseDate'] != null && headerMap['lastPurchaseDate'] != -1
            ? DateTime.tryParse(row[headerMap['lastPurchaseDate']!].toString())
            : null;
        bool isComplementary = headerMap['isComplementary'] != null && headerMap['isComplementary'] != -1
            ? row[headerMap['isComplementary']!].toString().toLowerCase() == 'true'
            : false;
        List<String> complementaryProductIds = headerMap['complementaryProductIds'] != null &&
                headerMap['complementaryProductIds'] != -1
            ? row[headerMap['complementaryProductIds']!].toString().split(',')
            : [];
        bool isSeasonal = headerMap['isSeasonal'] != null && headerMap['isSeasonal'] != -1
            ? row[headerMap['isSeasonal']!].toString().toLowerCase() == 'true'
            : false;
        DateTime? seasonStart = headerMap['seasonStart'] != null && headerMap['seasonStart'] != -1
            ? DateTime.tryParse(row[headerMap['seasonStart']!].toString())
            : null;
        DateTime? seasonEnd = headerMap['seasonEnd'] != null && headerMap['seasonEnd'] != -1
            ? DateTime.tryParse(row[headerMap['seasonEnd']!].toString())
            : null;
        int purchaseCount = headerMap['purchaseCount'] != null && headerMap['purchaseCount'] != -1
            ? int.tryParse(row[headerMap['purchaseCount']!].toString()) ?? 0
            : 0;
        int recentPurchaseCount = headerMap['recentPurchaseCount'] != null && headerMap['recentPurchaseCount'] != -1
            ? int.tryParse(row[headerMap['recentPurchaseCount']!].toString()) ?? 0
            : 0;
        int reviewCount = headerMap['reviewCount'] != null && headerMap['reviewCount'] != -1
            ? int.tryParse(row[headerMap['reviewCount']!].toString()) ?? 0
            : 0;
        int itemQuantity = headerMap['itemQuantity'] != null && headerMap['itemQuantity'] != -1
            ? int.tryParse(row[headerMap['itemQuantity']!].toString()) ?? 0
            : 0;
        int views = headerMap['views'] != null && headerMap['views'] != -1
            ? int.tryParse(row[headerMap['views']!].toString()) ?? 0
            : 0;
        int clicks = headerMap['clicks'] != null && headerMap['clicks'] != -1
            ? int.tryParse(row[headerMap['clicks']!].toString()) ?? 0
            : 0;
        int favorites = headerMap['favorites'] != null && headerMap['favorites'] != -1
            ? int.tryParse(row[headerMap['favorites']!].toString()) ?? 0
            : 0;
        int timeSpent = headerMap['timeSpent'] != null && headerMap['timeSpent'] != -1
            ? int.tryParse(row[headerMap['timeSpent']!].toString()) ?? 0
            : 0;
        List<String> consumptionTime = headerMap['consumptionTime'] != null && headerMap['consumptionTime'] != -1
            ? row[headerMap['consumptionTime']!].toString().split(',')
            : [];
        List<String> weather = headerMap['weather'] != null && headerMap['weather'] != -1
            ? row[headerMap['weather']!].toString().split(',')
            : [];
        num? rating = headerMap['rating'] != null && headerMap['rating'] != -1
            ? num.tryParse(row[headerMap['rating']!].toString()) ?? 0
            : null;
        int userViews = headerMap['userViews'] != null && headerMap['userViews'] != -1
            ? int.tryParse(row[headerMap['userViews']!].toString()) ?? 0
            : 0;
        int userTimeSpent = headerMap['userTimeSpent'] != null && headerMap['userTimeSpent'] != -1
            ? int.tryParse(row[headerMap['userTimeSpent']!].toString()) ?? 0
            : 0;

        // Handle categories (now a List<Category>)
        List<Category> categories = [];
        if (headerMap['categories'] != null && headerMap['categories'] != -1) {
          List<String> categoryNames = row[headerMap['categories']!].toString().split(',');
          List<String> categoryImageUrls = headerMap['categoryImageUrls'] != null &&
                  headerMap['categoryImageUrls'] != -1
              ? row[headerMap['categoryImageUrls']!].toString().split(',')
              : List.filled(categoryNames.length, '');
          List<String> subcategoryNames = headerMap['subcategoryNames'] != null &&
                  headerMap['subcategoryNames'] != -1
              ? row[headerMap['subcategoryNames']!].toString().split(',')
              : [];
          List<String> subcategoryImageUrls = headerMap['subcategoryImageUrls'] != null &&
                  headerMap['subcategoryImageUrls'] != -1
              ? row[headerMap['subcategoryImageUrls']!].toString().split(',')
              : List.filled(subcategoryNames.length, '');

          for (int j = 0; j < categoryNames.length; j++) {
            String categoryName = categoryNames[j].trim();
            String categoryImageUrl = j < categoryImageUrls.length ? categoryImageUrls[j].trim() : '';
            List<Subcategory> subcategoriesForCategory = [];
            // Assuming subcategories are comma-separated and correspond to categories
            int subcatIndex = subcategoryNames.indexWhere((name) => name.startsWith('$categoryName:'));            if (subcatIndex != -1) {
              subcategoriesForCategory = subcategoryNames
                  .skip(subcatIndex)
                  .takeWhile((name) => name.startsWith('$categoryName:'))
                  .map((name) => Subcategory(
                        name: name.replaceFirst('$categoryName:', '').trim(),
                        imageUrl: subcatIndex < subcategoryImageUrls.length
                            ? subcategoryImageUrls[subcatIndex].trim()
                            : '',
                      ))
                  .toList();
            }
            categories.add(Category(
              name: categoryName,
              imageUrl: categoryImageUrl,
              subcategories: subcategoriesForCategory,
            ));
          }
        }
        if (categories.isEmpty) {
          categories.add(Category(name: 'Uncategorized', imageUrl: '', subcategories: []));
        }

        // Handle varieties
        List<Variety> varieties = [];
        if (headerMap['varieties'] != null && headerMap['varieties'] != -1) {
          String varietyData = row[headerMap['varieties']!].toString();
          varieties = _getVarietiesFromRow(varietyData);
        }

        // Create Product object with updated fields
        Product product = Product(
          id: id,
          name: name,
          basePrice: basePrice,
          description: description,
          categories: categories,
          units: units,
          tags: tags,
          varieties: varieties,
          pictureUrl: pictureUrl,
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
          consumptionTime: consumptionTime,
          isFresh: isFresh,
          isLocallySourced: isLocallySourced,
          isOrganic: isOrganic,
          hasHealthBenefits: hasHealthBenefits,
          hasDiscounts: hasDiscounts,
          discountedPrice: discountedPrice,
          isEcoFriendly: isEcoFriendly,
          isSuperfood: isSuperfood,

          weather: weather,
          rating: rating,
          genomicAlternatives: [], // Default value as not in CSV
          discountedPriceStream2: null, // Not applicable from CSV
          groupDiscount: 0.0, // Default value
          groupSize: 0, // Default value
          currentGroupMembers: 0, // Default value
          minPrice: 0.0, // Default value
          isGroupActive: false, // Default value
          reviews: [], // Default value as not in CSV
        );

        // Upload the product to Firestore
        await _firestore.collection('products').doc(product.id).set(product.toMap());
      }

      print('${csvData.length - 1} products added successfully from CSV!');
    } catch (e) {
      print('Error reading CSV file: $e');
    }
  }

  // Helper method to parse varieties from a row
  List<Variety> _getVarietiesFromRow(String varietyData) {
    List<String> varietyEntries = varietyData.split(';'); // Assuming semicolon separates varieties
    List<Variety> varieties = [];
    for (String entry in varietyEntries) {
      List<String> parts = entry.split(','); // Assuming comma separates variety fields
      if (parts.isNotEmpty) {
        String name = parts[0].trim();
        String color = parts.length > 1 ? parts[1].trim() : '';
        String size = parts.length > 2 ? parts[2].trim() : '';
        String imageUrl = parts.length > 3 ? parts[3].trim() : '';
        double price = parts.length > 4 ? double.tryParse(parts[4]) ?? 0.0 : 0.0;
        varieties.add(Variety(
          name: name,
          color: color,
          size: size,
          imageUrl: imageUrl,
          price: price,
          discountedPriceStream: null, // No stream from CSV
        ));
      }
    }
    return varieties;
  }
}