import 'package:http/http.dart' as http;
import 'dart:convert';

class MLService {
  // OpenAI API Key (Replace with your own API key)
  final String apiKey = 'your_openai_api_key';

  // Use OpenAI's ChatGPT to recommend meals based on past purchases
  Future<List<String>> recommendMeals(List<String> pastPurchases,
      [selectedHealthCondition]) async {
    try {
      // Create a request prompt for ChatGPT
      String prompt =
          'Given these past purchases: ${pastPurchases.join(", ")}, suggest 3 meal recommendations.';

      // Call the ChatGPT API
      List<String> recommendations = await _callChatGPT(prompt);
      return recommendations;
    } catch (e) {
      throw Exception('Error in recommending meals: $e');
    }
  }

  // Helper function to call the OpenAI API and get meal recommendations
  Future<List<String>> _callChatGPT(String prompt) async {
    try {
      // Define the headers for the API request
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      // Create the request body with the prompt
      final body = json.encode({
        'model':
            'gpt-3.5-turbo', // You can use other models like 'gpt-3.5-turbo' if preferred
        'messages': [
          {
            'role': 'system',
            'content': 'You are a meal recommendation assistant.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 100,
        'temperature': 0.7,
      });

      // Send the HTTP request to the OpenAI API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: headers,
        body: body,
      );

      // Parse the response from OpenAI
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final chatResponse = jsonResponse['choices'][0]['message']['content'];

        // Split the response into a list of recommendations (assuming comma separation)
        List<String> recommendations =
            chatResponse.split(',').map((s) => s.trim()).toList();
        return recommendations;
      } else {
        throw Exception(
            'Failed to get response from ChatGPT API: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error in _callChatGPT: $e');
    }
  }
}
