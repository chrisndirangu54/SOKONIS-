// social_media_marketer.dart (Server-side with Firebase Cloud Functions)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:functions_framework/functions_framework.dart';
import 'package:grocerry/screens/admin_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

// Firebase Functions entry point for stream listening
@CloudFunction()
Future<Map<String, dynamic>> initializeSocialMediaMarketer(
    CloudEvent event, RequestContext context) async {
  final productProvider = ProductProvider();
  final marketer = SocialMediaMarketer(productProvider: productProvider);
  marketer._listenToProductStreams();
  return {
    'status': 'success',
    'message': 'Social Media Marketer initialized and listening to streams'
  };
}

// HTTP-triggered function for cleanup (to be scheduled via Pub/Sub)
@CloudFunction()
Future<Map<String, dynamic>> cleanupOldFiles(http.Request request) async {
  final firestore = FirebaseFirestore.instance;
  final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

  try {
    final snapshot = await firestore
        .collection('storage_files')
        .where('uploadTimestamp', isLessThan: Timestamp.fromDate(twoDaysAgo))
        .get();

    const storageBucket = 'your-app.appspot.com'; // Replace with your bucket
    const storageBaseUrl =
        'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o';
    const authToken = 'your_firebase_auth_token'; // Replace with real token

    for (var doc in snapshot.docs) {
      final filePath = doc['path'];
      final deleteUrl = '$storageBaseUrl/$filePath';
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        await doc.reference.delete();
        print('Deleted file from Storage: $filePath');
      } else {
        print('Failed to delete file $filePath: ${response.body}');
      }
    }
    return {'status': 'success', 'message': 'Old files cleaned up'};
  } catch (e) {
    print('Error cleaning up old files: $e');
    return {'status': 'error', 'message': 'Failed to clean up old files: $e'};
  }
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
  final ProductProvider productProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PlatformSwitchManager switchManager;
  DateTime? lastPostTime;

  final String _storageBucket =
      'your-app.appspot.com'; // Replace with your Firebase Storage bucket
  final String _firebaseStorageBaseUrl =
      'https://firebasestorage.googleapis.com/v0/b/';
  final String _firebaseAuthToken = 'your_firebase_auth_token';

  DateTime? lastUpdateTime; // Replace with real token

  SocialMediaMarketer(
      {required this.productProvider, PlatformSwitchManager? switchManager})
      : switchManager = switchManager ?? const PlatformSwitchManager() {
    _initializeMarketer();
  }

  void _initializeMarketer() {
    print('Social Media Marketer initialized on server.');
  }

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
        _createAndPostContent(product, 'New Product Alert!',
            '${product.name} is now available! Grab it for \$${product.basePrice}.');
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

      final File? audioFile =
          await _generateAIMusic(musicPrompt, duration, tempDir);

      final videoFileName =
          'temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final videoFile = File('${tempDir.path}/$videoFileName');

      List<String> ffmpegCommand = ['-loop', '1', '-i', imageFile.path];
      if (audioFile != null && audioFile.existsSync()) {
        ffmpegCommand.addAll(['-i', audioFile.path]);
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
        return audioFile;
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
        await rootBundle.loadString('assets/comfortaa-bold.fnt');

    // Load the .png file associated with the .fnt
    final ByteData fontImageData =
        await rootBundle.load('assets/comfortaa-bold.png');
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

  // **Upload to Firebase Storage with Tracking for Deletion**
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

        // Store metadata in Firestore for deletion tracking
        await _firestore.collection('storage_files').add({
          'path': path,
          'uploadTimestamp': FieldValue.serverTimestamp(),
        });

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

  Future<void> _postToTikTok(
      String contentUrl, String caption, String productId,
      {bool isSponsored = false}) async {
    if (!switchManager.getSwitch('tiktok')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);

    // Post content to TikTok
    final postResponse = await http.post(
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

    if (postResponse.statusCode == 200) {
      print('Posted to TikTok with geotag: $geoTagLocation');
      final postId = jsonDecode(
          postResponse.body)['id']; // Assuming TikTok returns a post ID

      // Promote the post as a sponsored ad if specified
      if (isSponsored) {
        const adUrl =
            'https://business-api.tiktok.com/open_api/v1.3/ad/create/';
        final adResponse = await http.post(
          Uri.parse(adUrl),
          headers: {
            'Authorization': 'Bearer $_tiktokApiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'advertiser_id': '<YOUR_ADVERTISER_ID>',
            'adgroup_id':
                '<YOUR_ADGROUP_ID>', // Pre-create an ad group in TikTok Ads Manager
            'creative': {
              'video_id': postId,
              'call_to_action': 'SHOP_NOW',
            },
            'budget': 500, // Example budget in cents ($5.00)
            'schedule_type': 'SCHEDULE_START_END',
            'start_time': DateTime.now().toIso8601String(),
            'end_time':
                DateTime.now().add(const Duration(days: 2)).toIso8601String(),
            'targeting': {
              'location': [geoTagLocation],
            },
          }),
        );
        if (adResponse.statusCode == 200) {
          print('Sponsored ad created for TikTok post $postId');
        } else {
          print('Failed to create TikTok sponsored ad: ${adResponse.body}');
        }
      }
    } else {
      print('Failed to post to TikTok: ${postResponse.body}');
    }
  }

  Future<void> _postToFacebook(
      String contentUrl, String caption, bool isVideo, String productId,
      {bool isSponsored = false}) async {
    if (!switchManager.getSwitch('facebook')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);

    // Base URL for posting
    final baseUrl = isVideo ? '$_facebookApiUrl/../videos' : _facebookApiUrl;
    final postResponse = await http.post(
      Uri.parse(baseUrl),
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

    if (postResponse.statusCode == 200) {
      print('Posted to Facebook with geotag: $geoTagLocation');
      final postId = jsonDecode(postResponse.body)['id'];

      // Boost the post as a sponsored ad if specified
      if (isSponsored) {
        const adUrl =
            'https://graph.facebook.com/v20.0/act_<YOUR_AD_ACCOUNT_ID>/adsets';
        final adResponse = await http.post(
          Uri.parse(adUrl),
          headers: {
            'Authorization': 'Bearer $_facebookApiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'name': 'Sponsored Post for $productId',
            'status': 'ACTIVE',
            'campaign_id':
                '<YOUR_CAMPAIGN_ID>', // Pre-create a campaign in Ads Manager
            'optimization_goal': 'POST_ENGAGEMENT',
            'billing_event': 'IMPRESSIONS',
            'bid_amount': 100, // In cents, e.g., $1.00
            'daily_budget': 500, // In cents, e.g., $5.00
            'targeting': {
              'geo_locations': {
                'custom_locations': [
                  {'name': geoTagLocation}
                ]
              },
            },
            'promoted_object': {
              'page_id': '<YOUR_PAGE_ID>',
              'object_id': postId
            },
          }),
        );
        if (adResponse.statusCode == 200) {
          print('Sponsored ad created for post $postId');
        } else {
          print('Failed to create sponsored ad: ${adResponse.body}');
        }
      }
    } else {
      print('Failed to post to Facebook: ${postResponse.body}');
    }
  }

  Future<void> _postToInstagram(
      String contentUrl, String caption, bool isVideo, String productId,
      {bool isSponsored = false}) async {
    if (!switchManager.getSwitch('instagram')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);

    final postResponse = await http.post(
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

    if (postResponse.statusCode == 200) {
      print('Posted to Instagram with geotag: $geoTagLocation');
      final postId = jsonDecode(postResponse.body)['id'];

      if (isSponsored) {
        const adUrl =
            'https://graph.facebook.com/v20.0/act_<YOUR_AD_ACCOUNT_ID>/adsets'; // Meta Ads API
        final adResponse = await http.post(
          Uri.parse(adUrl),
          headers: {
            'Authorization': 'Bearer $_instagramApiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'name': 'Sponsored Post for ${productId}',
            'status': 'ACTIVE',
            'campaign_id': '<YOUR_CAMPAIGN_ID>',
            'optimization_goal': 'POST_ENGAGEMENT',
            'billing_event': 'IMPRESSIONS',
            'bid_amount': 100,
            'daily_budget': 500,
            'targeting': {
              'geo_locations': {
                'custom_locations': [
                  {'name': geoTagLocation}
                ]
              },
            },
            'promoted_object': {
              'instagram_post_id': postId
            }, // Instagram-specific
          }),
        );
        if (adResponse.statusCode == 200) {
          print('Sponsored ad created for Instagram post $postId');
        } else {
          print('Failed to create Instagram sponsored ad: ${adResponse.body}');
        }
      }
    } else {
      print('Failed to post to Instagram: ${postResponse.body}');
    }
  }

  Future<void> _postToTwitter(
      String contentUrl, String caption, String productId,
      {bool isSponsored = false}) async {
    if (!switchManager.getSwitch('twitter')) return;
    final geoTagLocation = await _getTopConsumerLocation(productId);

    final postResponse = await http.post(
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

    if (postResponse.statusCode == 201) {
      print('Posted to Twitter with geotag: $geoTagLocation');
      final tweetId = jsonDecode(postResponse.body)['data']['id'];

      if (isSponsored) {
        const adUrl =
            'https://ads-api.twitter.com/12/accounts/<YOUR_ACCOUNT_ID>/promoted_tweets';
        final adResponse = await http.post(
          Uri.parse(adUrl),
          headers: {
            'Authorization': 'Bearer $_twitterApiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'line_item_id':
                '<YOUR_LINE_ITEM_ID>', // Pre-create in Twitter Ads Manager
            'tweet_ids': [tweetId],
          }),
        );
        if (adResponse.statusCode == 200 || adResponse.statusCode == 201) {
          print('Promoted Tweet created for tweet $tweetId');
        } else {
          print('Failed to promote Tweet: ${adResponse.body}');
        }
      }
    } else {
      print('Failed to post to Twitter: ${postResponse.body}');
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
      String contentUrl, String caption, bool isVideo, String productId,
      {bool isSponsored = false}) async {
    if (isVideo) {
      if (switchManager.getSwitch('tiktok')) {
        await _postToTikTok(contentUrl, caption, productId,
            isSponsored: isSponsored);
      }
      if (switchManager.getSwitch('facebook')) {
        await _postToFacebook(contentUrl, caption, true, productId,
            isSponsored: isSponsored);
      }
      if (switchManager.getSwitch('instagram')) {
        await _postToInstagram(contentUrl, caption, true, productId,
            isSponsored: isSponsored);
      }
    } else {
      if (switchManager.getSwitch('facebook')) {
        await _postToFacebook(contentUrl, caption, false, productId,
            isSponsored: isSponsored);
      }
      if (switchManager.getSwitch('instagram')) {
        await _postToInstagram(contentUrl, caption, false, productId,
            isSponsored: isSponsored);
      }
      if (switchManager.getSwitch('twitter')) {
        await _postToTwitter(contentUrl, caption, productId,
            isSponsored: isSponsored);
      }
    }
    if (switchManager.getSwitch('googleAds')) {
      await _postToGoogleAds(contentUrl, caption, isVideo, productId);
    }
  }

  Future<void> _createAndPostContent(
      Product product, String title, String baseMessage,
      {bool isSponsored = false}) async {
    try {
      bool isVideo = DateTime.now().second % 2 == 0;
      String contentUrl = await _generateVisualContent(product, isVideo);
      String embeddedContentUrl =
          isVideo ? contentUrl : await _embedTextOnContent(contentUrl, title);
      String caption = await _createChatGptCaption(baseMessage, product);
      await _postToAllPlatforms(
          embeddedContentUrl, caption, isVideo, product.id,
          isSponsored: isSponsored);
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

  Future<void> createAndPostManual(
      Product product, String title, String message,
      {bool isSponsored = false}) async {
    await _createAndPostContent(product, title, message,
        isSponsored: isSponsored);
  }
}
