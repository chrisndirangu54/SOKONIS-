// social_media_marketer.dart (Server-side with Firebase Cloud Functions)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:functions_framework/functions_framework.dart';
import 'package:grocerry/screens/admin_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Still needed for storage and lookups
import '../providers/product_provider.dart'; // Import ProductProvider
import '../models/product.dart';

// Firebase Functions entry point (runs on server startup)
@CloudFunction()
Future<Map<String, dynamic>> initializeSocialMediaMarketer(
    CloudEvent event, RequestContext context) async {
  final productProvider = ProductProvider(); // Instantiate server-side
  final marketer = SocialMediaMarketer(productProvider: productProvider);
  marketer._listenToProductStreams(); // Start listening to streams on server
  return {
    'status': 'success',
    'message': 'Social Media Marketer initialized and listening to streams'
  };
}

class SocialMediaMarketer {
  final String _aiImageApiUrl = 'https://api.generative-ai.com/v1/images';
  final String _aiVideoApiUrl = 'https://api.generative-ai.com/v1/videos';
  final String _openAiApiUrl = 'https://api.openai.com/v1/completions';
  final String _tiktokApiUrl = 'https://api.tiktok.com/v1/post';
  final String _facebookApiUrl = 'https://graph.facebook.com/v20.0/me/photos';
  final String _instagramApiUrl = 'https://graph.instagram.com/v20.0/me/media';
  final String _twitterApiUrl = 'https://api.twitter.com/2/tweets';
  final String _googleAdsApiUrl = 'https://api.google.com/ads/v1/campaigns';
  final String _aiApiKey = 'your_generative_ai_api_key_here';
  final String _openAiApiKey = 'your_openai_api_key_here';
  final String _tiktokApiKey = 'your_tiktok_api_key_here';
  final String _facebookApiKey = 'your_facebook_access_token_here';
  final String _instagramApiKey = 'your_instagram_access_token_here';
  final String _twitterApiKey = 'your_twitter_bearer_token_here';
  final String _googleAdsApiKey = 'your_google_ads_api_key_here';
  final ProductProvider productProvider; // Required ProductProvider instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PlatformSwitchManager switchManager;
  // Firebase Storage config (replace with your bucket)
  final String _storageBucket =
      'your-app.appspot.com'; // Replace with your Firebase Storage bucket
  final String _firebaseStorageBaseUrl =
      'https://firebasestorage.googleapis.com/v0/b/';
  final String _firebaseAuthToken = 'your_firebase_auth_token';

  DateTime? lastUpdateTime; // Obtain via Firebase Admin SDK or service account

  SocialMediaMarketer(
      {required this.productProvider, PlatformSwitchManager? switchManager})
      : switchManager = switchManager ?? PlatformSwitchManager() {
    _initializeMarketer();
  }

  void _initializeMarketer() {
    print('Social Media Marketer initialized on server.');
  }

  // **Listen to Product Streams (Server-Side)**
  void _listenToProductStreams() {
    productProvider.productsStream.listen((products) async {
      await _handleNewProductUpdates(products);
    });

    productProvider.seasonallyAvailableStream.listen((seasonalProducts) async {
      await _handleSeasonalProductUpdates(seasonalProducts);
    });

    productProvider.nearbyUsersBoughtStream.listen((nearbyProducts) async {
      await _handleTrendingProductUpdates(nearbyProducts);
    });

    productProvider.timeOfDayProductsStream.listen((timeOfDayProducts) async {
      await _handleTimeOfDayProductUpdates(timeOfDayProducts);
    });

    productProvider.weatherProductsStream.listen((weatherProducts) async {
      await _handleWeatherProductUpdates(weatherProducts);
    });

    print('Server-side ProductProvider stream listeners activated.');
  }

  // **Handle Stream Updates**
  Future<void> _handleNewProductUpdates(List<Product> products) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  lastUpdateTime ?? DateTime.fromMillisecondsSinceEpoch(0)))
          .orderBy('createdAt', descending: true)
          .get();
      final List<Product> newProducts = querySnapshot.docs.map((doc) {
        return Product.fromFirestore(); // Assuming Product.fromFirestore exists
      }).toList();
      lastUpdateTime = DateTime.now();
      for (var product in newProducts) {
        _createAndPostContent(product, 'Seasonal Special!',
            '${product.name} is in season now! Grab it for \$${product.basePrice}.');
      }
    } catch (e) {
      print('Error fetching new products: $e');
    }
  }

  Future<void> _handleSeasonalProductUpdates(
      List<Product> seasonalProducts) async {
    for (var product in seasonalProducts) {
      await _createAndPostContent(product, 'Seasonal Special!',
          '${product.name} is in season now! Grab it for \$${product.basePrice}.');
    }
  }

  Future<void> _handleTrendingProductUpdates(
      List<Product> trendingProducts) async {
    for (var product in trendingProducts) {
      await _createAndPostContent(product, 'Trending Now!',
          '${product.name} is hot near you! Get it for \$${product.basePrice}.');
    }
  }

  Future<void> _handleTimeOfDayProductUpdates(
      List<Product> timeOfDayProducts) async {
    for (var product in timeOfDayProducts) {
      await _createAndPostContent(product, 'Time of Day Special!',
          '${product.name} is perfect right now for just \$${product.basePrice}!');
    }
  }

  Future<void> _handleWeatherProductUpdates(
      List<Product> weatherProducts) async {
    for (var product in weatherProducts) {
      await _createAndPostContent(product, 'Weather Perfect Pick!',
          '${product.name} suits today’s weather at \$${product.basePrice}!');
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
      return await _fetchCopyrightFreeContent(product, isVideo);
    }
  }

  Future<String> _fetchCopyrightFreeContent(
      Product product, bool isVideo) async {
    final sourceUrl = isVideo
        ? 'https://pixabay.com/api/videos/?key=your_pixabay_key&q=${product.name}'
        : 'https://pixabay.com/api/?key=your_pixabay_key&q=${product.name}';
    try {
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        if (result['hits'] != null && result['hits'].isNotEmpty) {
          return isVideo
              ? (result['hits'][0]['videos']['medium']['url'] ??
                  result['hits'][0]['largeImageURL'])
              : result['hits'][0]['largeImageURL'];
        }
      }
      if (product.pictureUrl != null && product.pictureUrl!.isNotEmpty) {
        return isVideo
            ? await _createVideoFromImage(product.pictureUrl!,
                textOverlay: product.name,
                musicPrompt: 'upbeat background music',
                duration: 7.0,
                resolution: '1920x1080',
                zoomIn: true)
            : product.pictureUrl!;
      }
      throw Exception(
          'Failed to fetch copyright-free content and no valid pictureUrl');
    } catch (e) {
      print('Error fetching copyright-free content: $e');
      if (product.pictureUrl != null && product.pictureUrl!.isNotEmpty) {
        return isVideo
            ? await _createVideoFromImage(product.pictureUrl!,
                textOverlay: product.name,
                musicPrompt: 'upbeat background music',
                duration: 7.0,
                resolution: '1920x1080',
                zoomIn: true)
            : product.pictureUrl!;
      }
      throw Exception('Failed to fetch copyright-free content');
    }
  }

  Future<String> _createVideoFromImage(
    String imageUrl, {
    String textOverlay = '',
    String musicPrompt = 'upbeat background music',
    double duration = 5.0,
    String resolution = '1280x720',
    bool zoomIn = true,
  }) async {
    final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
    try {
      final imageResponse = await http.get(Uri.parse(imageUrl));
      if (imageResponse.statusCode != 200) {
        throw Exception('Failed to download image from $imageUrl');
      }
      final imageBytes = imageResponse.bodyBytes;

      final tempDir = Directory.systemTemp;
      final imageFileName =
          'temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageFile = File('${tempDir.path}/$imageFileName');
      await imageFile.writeAsBytes(imageBytes);

      // Use File? instead of String for audioFile
      final File? audioFile =
          await _generateAIMusic(musicPrompt, duration, tempDir);

      final videoFileName =
          'temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final videoFile = File('${tempDir.path}/$videoFileName');

      List<String> ffmpegCommand = ['-loop', '1', '-i', imageFile.path];
      if (audioFile != null && audioFile.existsSync()) {
        ffmpegCommand.addAll(['-i', audioFile.path]); // Use audioFile.path here
      }

      List<String> filters = [
        'zoompan=z=\'${zoomIn ? 'zoom+0.002' : 'zoom-0.002'}\':d=125:s=$resolution',
        'fade=t=in:st=0:d=1,fade=t=out:st=${duration - 1}:d=1',
      ];
      if (textOverlay.isNotEmpty) {
        filters.add(
          'drawtext=text=\'$textOverlay\':fontcolor=white:fontsize=48:box=1:boxcolor=black@0.5:'
          'x=(w-text_w)/2:y=(h-text_h-50):enable=\'between(t,0,$duration)\'',
        );
      }

      ffmpegCommand.addAll([
        '-vf',
        filters.join(','),
        '-c:v',
        'libx264',
        '-t',
        duration.toString(),
        '-r',
        '30'
      ]);
      if (audioFile != null && audioFile.existsSync()) {
        ffmpegCommand.addAll(['-c:a', 'aac', '-shortest']);
      }
      ffmpegCommand.addAll(['-y', videoFile.path]);

      int rc = await _flutterFFmpeg.executeWithArguments(ffmpegCommand);
      if (rc == 0) {
        print('Video created successfully at ${videoFile.path}');
        final storageUrl =
            await _uploadToStorage(videoFile, 'videos/$videoFileName');
        return storageUrl;
      } else {
        throw Exception('FFmpeg execution failed with return code $rc');
      }
    } catch (e) {
      print('Error creating video from image: $e');
      return imageUrl;
    }
  }

  Future<File?> _generateAIMusic(
      String prompt, double duration, Directory tempDir) async {
    try {
      const apiUrl = 'https://example-ai-music-generator.com/api/generate';
      const apiKey = 'your_free_api_key';
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey'
        },
        body: jsonEncode(
            {'prompt': prompt, 'duration': duration, 'format': 'mp3'}),
      );
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        final audioFileName =
            'temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final audioFile = File('${tempDir.path}/$audioFileName');
        await audioFile.writeAsBytes(audioBytes);
        print('AI music generated successfully at ${audioFile.path}');
        return audioFile; // Return File instead of String
      }
      return null;
    } catch (e) {
      print('Error generating AI music: $e');
      return null;
    }
  }

  Future<img.BitmapFont> loadFont() async {
    // Load the .fnt file as a string
    final String fontData =
        await rootBundle.loadString('assets/fonts/arial_24.fnt');

    // Load the .png file associated with the .fnt
    final ByteData fontImageData =
        await rootBundle.load('assets/fonts/arial_24.png');
    final Uint8List fontImageBytes = fontImageData.buffer.asUint8List();

    // Decode the image
    final img.Image fontImage = img.decodeImage(fontImageBytes)!;

    // Create the BitmapFont using the .fnt and associated image
    final img.BitmapFont font = img.BitmapFont.fromFnt(fontData, fontImage);

    return font;
  }

  Future<String> _embedTextOnContent(String contentUrl, String text) async {
    try {
      img.BitmapFont font = await loadFont();

      final response = await http.get(Uri.parse(contentUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image from $contentUrl');
      }
      final imageBytes = response.bodyBytes;

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      const fontSize = 24;
      const String textColor = '#FFFFFF';
      final int colorValue = int.parse(textColor.replaceFirst('#', '0xff'));
      final imgColor = img.Color.fromRgba(
        (colorValue >> 16) & 0xFF,
        (colorValue >> 8) & 0xFF,
        colorValue & 0xFF,
        (colorValue >> 24) & 0xFF,
      );

      final textWidth = text.length * 10;
      final x = (image.width - textWidth) ~/ 2;
      final y = image.height - fontSize - 10;

      img.drawString(image, font, x, y, textColor);

      final editedImageBytes = img.encodePng(image);
      final tempDir = Directory.systemTemp;
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(editedImageBytes);

      final storageUrl = await _uploadToStorage(file, 'images/$fileName');
      return storageUrl;
    } catch (e) {
      print('Error embedding text on content: $e');
      throw Exception('Failed to embed text on content');
    }
  }

  Future<String> _fetchPositiveTrendingTopic() async {
    final response = await http.post(
      Uri.parse(_openAiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'prompt': 'Provide a short, engaging trending topic in Kenya that has a positive sentiment. '
            'Ensure it does not mention individuals, organizations, politics, or unethical topics. '
            'Format it as a natural attention-grabbing phrase, suitable to blend into a message.',
        'max_tokens': 20,
      }),
    );
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      return result['choices'][0]['text'].trim();
    } else {
      return 'Something exciting is happening in Kenya!';
    }
  }

  Future<String> _createChatGptCaption(
      String baseMessage, Product product) async {
    final trendingTopic = await _fetchPositiveTrendingTopic();
    final prompt = '''
      Create a short, engaging social media caption for "${product.name}" at \$${product.basePrice}. 
      Base message: "$baseMessage". Incorporate this trending topic: "$trendingTopic". 
      Keep it positive, catchy, and add hashtags (e.g., #GroceryDeals, #${product.name.replaceAll(' ', '')}).
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
    }
    return '$trendingTopic $baseMessage Get ${product.name} now! #GroceryDeals #${product.name.replaceAll(' ', '')}';
  }

  // **Upload to Firebase Storage (Server-Side)**
  Future<String> _uploadToStorage(File file, String path) async {
    try {
      final uploadUrl = '$_firebaseStorageBaseUrl$_storageBucket/o?name=$path';
      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $_firebaseAuthToken',
          'Content-Type': 'application/octet-stream',
        },
        body: await file.readAsBytes(),
      );

      if (response.statusCode == 200) {
        final downloadUrl =
            '$_firebaseStorageBaseUrl$_storageBucket/o/$path?alt=media';
        print('File uploaded to Firebase Storage: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception(
            'Failed to upload to Firebase Storage: ${response.body}');
      }
    } catch (e) {
      print('Error uploading to Firebase Storage: $e');
      throw Exception('Failed to upload file to storage');
    }
  }

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
    if (response.statusCode != 200) {
      print('Failed to post to TikTok: ${response.body}');
    }
  }

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
    if (response.statusCode != 200) {
      print('Failed to post to Facebook: ${response.body}');
    }
  }

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
    if (response.statusCode != 200) {
      print('Failed to post to Instagram: ${response.body}');
    }
  }

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
    if (response.statusCode != 201) {
      print('Failed to post to Twitter: ${response.body}');
    }
  }

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
        'headline': '${caption.split('!')[0]}!',
        'description': 'Shop now at our store!',
        'format': isVideo ? 'video' : 'image',
        'targeting': {
          'locations': [targetLocation]
        },
      }),
    );
    if (response.statusCode != 200) {
      print('Failed to post to Google Ads: ${response.body}');
    }
  }

  Future<void> _postToAllPlatforms(
      String contentUrl, String caption, bool isVideo, String productId) async {
    if (isVideo) {
      if (switchManager.getSwitch('tiktok')) {
        await _postToTikTok(contentUrl, caption, productId);
      }
      if (switchManager.getSwitch('facebook')) {
        await _postToFacebook(contentUrl, caption, true, productId);
      }
      if (switchManager.getSwitch('instagram')) {
        await _postToInstagram(contentUrl, caption, true, productId);
      }
    } else {
      if (switchManager.getSwitch('facebook')) {
        await _postToFacebook(contentUrl, caption, false, productId);
      }
      if (switchManager.getSwitch('instagram')) {
        await _postToInstagram(contentUrl, caption, false, productId);
      }
      if (switchManager.getSwitch('twitter')) {
        await _postToTwitter(contentUrl, caption, productId);
      }
    }
    if (switchManager.getSwitch('googleAds')) {
      await _postToGoogleAds(contentUrl, caption, isVideo, productId);
    }
  }

  Future<void> _createAndPostContent(
      Product product, String title, String baseMessage) async {
    try {
      bool isVideo = DateTime.now().second % 2 == 0;
      String contentUrl = await _generateVisualContent(product, isVideo);
      String embeddedContentUrl =
          isVideo ? contentUrl : await _embedTextOnContent(contentUrl, title);
      String caption = await _createChatGptCaption(baseMessage, product);
      await _postToAllPlatforms(
          embeddedContentUrl, caption, isVideo, product.id);
      await _storePostRecord(embeddedContentUrl, caption);
    } catch (e) {
      print('Error creating and posting content: $e');
    }
  }

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
}
