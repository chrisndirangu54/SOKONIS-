import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/screens/admin_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import '../providers/product_provider.dart'; // Import ProductProvider
import '../models/product.dart'; // Import the Product class

class SocialMediaMarketer {
  final String _aiImageApiUrl = 'https://api.generative-ai.com/v1/images';
  final String _aiVideoApiUrl = 'https://api.generative-ai.com/v1/videos';
  final String _openAiApiUrl = 'https://api.openai.com/v1/completions';
  final String _weatherApiUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  final String _tiktokApiUrl = 'https://api.tiktok.com/v1/post';
  final String _facebookApiUrl = 'https://graph.facebook.com/v20.0/me/photos';
  final String _instagramApiUrl = 'https://graph.instagram.com/v20.0/me/media';
  final String _twitterApiUrl = 'https://api.twitter.com/2/tweets';
  final String _googleAdsApiUrl = 'https://api.google.com/ads/v1/campaigns';
  final String _aiApiKey = 'your_generative_ai_api_key_here';
  final String _openAiApiKey = 'your_openai_api_key_here';
  final String _weatherApiKey = 'your_openweathermap_api_key_here';
  final String _tiktokApiKey = 'your_tiktok_api_key_here';
  final String _facebookApiKey = 'your_facebook_access_token_here';
  final String _instagramApiKey = 'your_instagram_access_token_here';
  final String _twitterApiKey = 'your_twitter_bearer_token_here';
  final String _googleAdsApiKey = 'your_google_ads_api_key_here';
  final ProductProvider? productProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PlatformSwitchManager switchManager; // New switch manager instance
  DateTime? lastPostTime;

  SocialMediaMarketer({
    this.productProvider,
    PlatformSwitchManager? switchManager,
  }) : switchManager = switchManager ?? PlatformSwitchManager() {
    _initializeMarketer();
    if (productProvider != null) {
      _listenToProductStreams();
    }
  }

  // **Initialize the Social Media Marketer**
  void _initializeMarketer() {
    print('Social Media Marketer initialized.');
  }

  // **Listen to Product Streams**
  void _listenToProductStreams() {
    if (productProvider != null) {
      productProvider!.productsStream.listen((products) {
        _handleNewProductUpdates();
      });
      productProvider!.seasonallyAvailableStream.listen((seasonalProducts) {
        _handleSeasonalProductUpdates(seasonalProducts);
      });
      productProvider!.nearbyUsersBoughtStream.listen((nearbyProducts) {
        _handleTrendingProductUpdates(nearbyProducts);
      });
      productProvider!.timeOfDayProductsStream.listen((timeOfDayProducts) {
        _handleTimeOfDayProductUpdates(timeOfDayProducts);
      });
      productProvider!.weatherProductsStream.listen((weatherProducts) {
        _handleWeatherProductUpdates(weatherProducts);
      });
    }
  }

  // **Handle Stream Updates**
  Future<void> _handleNewProductUpdates() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  lastPostTime ?? DateTime.fromMillisecondsSinceEpoch(0)))
          .orderBy('createdAt', descending: true)
          .get();
      final List<Product> newProducts = querySnapshot.docs.map((doc) {
        return Product.fromFirestore();
      }).toList();
      lastPostTime = DateTime.now();
      for (var product in newProducts) {
        await _createAndPostContent(
          product,
          'New Product Launch!',
          'Check out our latest: ${product.name}! Only \$${product.basePrice}.',
        );
      }
    } catch (e) {
      print('Error fetching new products: $e');
    }
  }

  void _handleSeasonalProductUpdates(List<Product> seasonalProducts) {
    for (var product in seasonalProducts) {
      _createAndPostContent(
        product,
        'Seasonal Special!',
        '${product.name} is in season now! Grab it for \$${product.basePrice}.',
      );
    }
  }

  void _handleTrendingProductUpdates(List<Product> trendingProducts) {
    for (var product in trendingProducts) {
      _createAndPostContent(
        product,
        'Trending Now!',
        '${product.name} is hot near you! Get it for \$${product.basePrice}.',
      );
    }
  }

  void _handleTimeOfDayProductUpdates(List<Product> timeOfDayProducts) {
    for (var product in timeOfDayProducts) {
      _createAndPostContent(
        product,
        'Time of Day Special!',
        '${product.name} is perfect right now for just \$${product.basePrice}!',
      );
    }
  }

  void _handleWeatherProductUpdates(List<Product> weatherProducts) {
    for (var product in weatherProducts) {
      _createAndPostContent(
        product,
        'Weather Perfect Pick!',
        '${product.name} suits today’s weather at \$${product.basePrice}!',
      );
    }
  }

  // **Get Top Consumer Location**
  Future<String> _getTopConsumerLocation(String productId) async {
    try {
      final querySnapshot = await _firestore
          .collection('purchases')
          .where('productId', isEqualTo: productId)
          .get();
      if (querySnapshot.docs.isEmpty) return 'Nairobi, Kenya';
      Map<String, int> locationCount = {};
      for (var doc in querySnapshot.docs) {
        String location = doc['location'] ?? 'Unknown';
        locationCount[location] = (locationCount[location] ?? 0) + 1;
      }
      String topLocation = 'Nairobi, Kenya';
      int maxCount = 0;
      locationCount.forEach((location, count) {
        if (count > maxCount) {
          maxCount = count;
          topLocation = location;
        }
      });
      return topLocation;
    } catch (e) {
      print('Error fetching top consumer location: $e');
      return 'Nairobi, Kenya';
    }
  }

  // **Generate Visual Content**
  Future<String> _generateVisualContent(Product product, bool isVideo) async {
    final apiUrl = isVideo ? _aiVideoApiUrl : _aiImageApiUrl;
    final prompt = isVideo
        ? 'Create a 15-second promotional video for ${product.name}. Highlight freshness and price (\$${product.basePrice}).'
        : 'Generate an image for ${product.name} in a vibrant setting with a price tag of \$${product.basePrice}.';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey'
      },
      body: jsonEncode({
        'prompt': prompt,
        'style': 'realistic',
        'resolution': isVideo ? '720p' : '1080x1080'
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['url'];
    } else {
      return _fetchCopyrightFreeContent(product, isVideo);
    }
  }

  // **Fetch Copyright-Free Content**
  Future<String> _fetchCopyrightFreeContent(
      Product product, bool isVideo) async {
    final sourceUrl = isVideo
        ? 'https://pixabay.com/api/videos/?key=your_pixabay_key&q=${product.name}'
        : 'https://pixabay.com/api/?key=your_pixabay_key&q=${product.name}';
    final response = await http.get(Uri.parse(sourceUrl));
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      return result['hits'][0]['largeImageURL'] ??
          result['hits'][0]['videos']['medium']['url'];
    } else {
      throw Exception('Failed to fetch copyright-free content');
    }
  }

  // **Embed Text on Content**
  Future<String> _embedTextOnContent(String contentUrl, String text) async {
    final response = await http.post(
      Uri.parse('https://api.image-editor.com/v1/edit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey'
      },
      body: jsonEncode({
        'contentUrl': contentUrl,
        'text': text,
        'font': 'Arial',
        'size': 24,
        'color': '#FFFFFF',
        'position': 'bottom-center'
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['editedUrl'];
    } else {
      throw Exception('Failed to embed text');
    }
  }

  // **Generate Caption with ChatGPT**
  Future<String> _createChatGptCaption(
      String baseMessage, Product product) async {
    final prompt = '''
      Create a short, engaging social media caption for "${product.name}" at \$${product.basePrice}. 
      Base message: "$baseMessage".  
      keep it positive, catchy, and add hashtags (e.g., #GroceryDeals, #${product.name.replaceAll(' ', '')}). 
      Ensure uniqueness.
    ''';
    final response = await http.post(
      Uri.parse(_openAiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey'
      },
      body: jsonEncode({
        'model': 'text-davinci-003',
        'prompt': prompt,
        'max_tokens': 60,
        'temperature': 0.9
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['choices'][0]['text'].trim();
    } else {
      return '$baseMessage Get this ${product.name}. Delivered at your doorstep in 30 minutes! #GroceryDeals #${product.name.replaceAll(' ', '')}';
    }
  }

  // **Post to TikTok**
  Future<void> _postToTikTok(
      String contentUrl, String caption, String productId) async {
    if (!switchManager.getSwitch('tiktok')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);
    final response = await http.post(
      Uri.parse(_tiktokApiUrl),
      headers: {
        'Authorization': 'Bearer $_tiktokApiKey',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'video_url': contentUrl,
        'description': caption,
        'privacy_level': 'public',
        'location': geoTagLocation,
      }),
    );
    if (response.statusCode == 200) {
      print('Posted to TikTok with geotag: $geoTagLocation');
    } else {
      print('Failed to post to TikTok: ${response.body}');
    }
  }

  // **Post to Facebook**
  Future<void> _postToFacebook(
      String contentUrl, String caption, bool isVideo, String productId) async {
    if (!switchManager.getSwitch('facebook')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);
    final response = await http.post(
      Uri.parse(isVideo ? '$_facebookApiUrl/../videos' : _facebookApiUrl),
      headers: {
        'Authorization': 'Bearer $_facebookApiKey',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        isVideo ? 'file_url' : 'url': contentUrl,
        'message': caption,
        'place': {'name': geoTagLocation},
      }),
    );
    if (response.statusCode == 200) {
      print('Posted to Facebook with geotag: $geoTagLocation');
    } else {
      print('Failed to post to Facebook: ${response.body}');
    }
  }

  // **Post to Instagram**
  Future<void> _postToInstagram(
      String contentUrl, String caption, bool isVideo, String productId) async {
    if (!switchManager.getSwitch('instagram')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);
    final response = await http.post(
      Uri.parse(_instagramApiUrl),
      headers: {
        'Authorization': 'Bearer $_instagramApiKey',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'media_type': isVideo ? 'VIDEO' : 'IMAGE',
        'media_url': contentUrl,
        'caption': caption,
        'location': {'name': geoTagLocation},
      }),
    );
    if (response.statusCode == 200) {
      print('Posted to Instagram with geotag: $geoTagLocation');
    } else {
      print('Failed to post to Instagram: ${response.body}');
    }
  }

  // **Post to Twitter**
  Future<void> _postToTwitter(
      String contentUrl, String caption, String productId) async {
    if (!switchManager.getSwitch('twitter')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);
    final response = await http.post(
      Uri.parse(_twitterApiUrl),
      headers: {
        'Authorization': 'Bearer $_twitterApiKey',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'text': caption,
        'media': {
          'media_urls': [contentUrl]
        },
        'place': {'full_name': geoTagLocation},
      }),
    );
    if (response.statusCode == 201) {
      print('Posted to Twitter with geotag: $geoTagLocation');
    } else {
      print('Failed to post to Twitter: ${response.body}');
    }
  }

  // **Post to Google Ads**
  Future<void> _postToGoogleAds(
      String contentUrl, String caption, bool isVideo, String productId) async {
    if (!switchManager.getSwitch('googleAds')) return;
    final targetLocation = await _getTopConsumerLocation(productId);
    final response = await http.post(
      Uri.parse(_googleAdsApiUrl),
      headers: {
        'Authorization': 'Bearer $_googleAdsApiKey',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'contentUrl': contentUrl,
        'headline': caption.split('!')[0] + '!',
        'description': 'Shop now at our store!',
        'format': isVideo ? 'video' : 'image',
        'targeting': {
          'locations': [targetLocation]
        },
      }),
    );
    if (response.statusCode == 200) {
      print('Posted to Google Ads targeting: $targetLocation');
    } else {
      print('Failed to post to Google Ads: ${response.body}');
    }
  }

  // **Post to All Platforms with Switches**
  Future<void> _postToAllPlatforms(
      String contentUrl, String caption, bool isVideo, String productId) async {
    if (isVideo) {
      if (switchManager.getSwitch('tiktok'))
        await _postToTikTok(contentUrl, caption, productId);
      if (switchManager.getSwitch('facebook'))
        await _postToFacebook(contentUrl, caption, true, productId);
      if (switchManager.getSwitch('instagram'))
        await _postToInstagram(contentUrl, caption, true, productId);
    } else {
      if (switchManager.getSwitch('facebook'))
        await _postToFacebook(contentUrl, caption, false, productId);
      if (switchManager.getSwitch('instagram'))
        await _postToInstagram(contentUrl, caption, false, productId);
      if (switchManager.getSwitch('twitter'))
        await _postToTwitter(contentUrl, caption, productId);
    }
    if (switchManager.getSwitch('googleAds'))
      await _postToGoogleAds(contentUrl, caption, isVideo, productId);
  }

  // **Main Method to Create and Post Content**
  Future<void> _createAndPostContent(
      Product product, String title, String baseMessage) async {
    try {
      bool isVideo = DateTime.now().second % 2 == 0;
      String contentUrl = await _generateVisualContent(product, isVideo);
      String embeddedContentUrl = await _embedTextOnContent(contentUrl, title);
      String caption = await _createChatGptCaption(baseMessage, product);
      await _postToAllPlatforms(
          embeddedContentUrl, caption, isVideo, product.id);
      await _storePostRecord(embeddedContentUrl, caption);
    } catch (e) {
      print('Error creating and posting content: $e');
    }
  }

  // **Store Post Record**
  Future<void> _storePostRecord(String contentUrl, String caption) async {
    try {
      await _firestore.collection('social_posts').add({
        'contentUrl': contentUrl,
        'caption': caption,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Post record stored successfully.');
    } catch (e) {
      print('Error storing post record: $e');
    }
  }

  // **Manual Trigger for Posting**
  Future<void> createAndPostManual(
      Product product, String title, String message) async {
    await _createAndPostContent(product, title, message);
  }
}
