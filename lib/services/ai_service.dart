import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore for analytics data

class AIService {
  static const apiKey =
      'YOUR_OPENAI_API_KEY'; // Replace with your OpenAI API Key
  final AnalyticsService _analyticsService =
      AnalyticsService(); // Analytics service instance

  Future<Map<String, dynamic>> getProductInsights(
      List<Map<String, dynamic>> productData, String productId) async {
    // Fetch product analytics data from Firestore
    final analyticsData =
        await _analyticsService.getProductAnalytics(productId);

    final url = Uri.parse('https://api.openai.com/v1/completions');

    // Craft the prompt to include performance data and analytics insights
    final prompt =
        'Analyze the following product performance data for product ID $productId: $productData. '
        'Also, consider the following analytics data: ${analyticsData.toString()}. '
        'Provide insights on sales trends, stock levels, user engagement, and future predictions.';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4', // or 'gpt-3.5-turbo'
      'prompt': prompt,
      'max_tokens': 500,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        // Decode the JSON response
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get product insights: ${response.body}');
      }
    } catch (e) {
      print('Error in API call: $e');
      return {};
    }
  }
}

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, int>> getProductAnalytics(String productId) async {
    int viewCount = 0;
    int clickCount = 0;
    int favoriteCount = 0;
    int timeSpentCount = 0;
    int purchaseCount = 0;

    final logsSnapshot = await _firestore
        .collection('user_logs')
        .where('productId', isEqualTo: productId)
        .get();

    for (var log in logsSnapshot.docs) {
      switch (log['event']) {
        case 'view':
          viewCount++;
          break;
        case 'click':
          clickCount++;
          break;
        case 'favorite':
          favoriteCount++;
          break;
        case 'timeSpent':
          timeSpentCount++;
          break;
        case 'purchaseCount':
          purchaseCount++;
          break;
      }
    }

    return {
      'views': viewCount,
      'clicks': clickCount,
      'favorites': favoriteCount,
      'timeSpent': timeSpentCount,
      'purchaseCount': purchaseCount,
    };
  }
}

class UserAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch analytics data for a specific product based on user activity
  Future<Map<String, int>> getUserProductAnalytics(
      String userId, String productId) async {
    int userViews = 0;
    int userClicks = 0;
    int userTimeSpent = 0;

    // Query user-specific logs for this product
    final logsSnapshot = await _firestore
        .collection('user_logs')
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: userId) // Filter by user
        .get();

    for (var log in logsSnapshot.docs) {
      switch (log['event']) {
        case 'view':
          userViews++;
          break;
        case 'click':
          userClicks++;
          break;
        case 'timeSpent':
          userTimeSpent++;
          break;
      }
    }

    return {
      'userViews': userViews,
      'userClicks': userClicks,
      'userTimeSpent': userTimeSpent,
    };
  }
}
