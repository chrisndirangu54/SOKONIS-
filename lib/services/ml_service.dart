import 'package:http/http.dart' as http;
import 'dart:convert';

class MLService {
  // OpenAI API Key (Replace with your own API key)
  final String apiKey = 'your_openai_api_key';

  // Use OpenAI's ChatGPT to recommend meals based on past purchases
  Future<List<Map<String, dynamic>>> recommendMeals(List<String> pastPurchases, int numberOfPeople,
      [selectedHealthCondition]) async {
    try {
      // Create a request prompt for ChatGPT
      String prompt =
          'Given these past purchases: ${pastPurchases.join(", ")}, suggest 3 meal recommendations (breakfast, lunch, super) for $numberOfPeople people.';

      // Call the ChatGPT API
      List<Map<String, dynamic>> recommendations = await _callChatGPT(prompt);
      return recommendations;
    } catch (e) {
      throw Exception('Error in recommending meals: $e');
    }
  }

  // Helper function to call the OpenAI API and get meal recommendations
  Future<List<Map<String, dynamic>>> _callChatGPT(String prompt) async {
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

      // Assuming chatResponse is a JSON string
      List<Map<String, dynamic>> recommendations = [];
      try {
        // Decode JSON string into a List<dynamic>
        final decoded = jsonDecode(chatResponse);
        if (decoded is List) {
          recommendations = decoded.cast<Map<String, dynamic>>().toList();
        } else {
          throw const FormatException('Expected a JSON list');
        }
      } catch (e) {
        // Fallback: Treat as comma-separated list if JSON parsing fails
        recommendations = chatResponse
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) {
              // Parse quantity and name if present (e.g., "10kg rice")
              final match = RegExp(r'(\d+\.?\d*)([a-zA-Z]+)?\s*(.*)').firstMatch(s);
              if (match != null) {
                return {
                  'quantity': double.tryParse(match.group(1)!)?.toInt() ?? 1,
                  'unit': match.group(2),
                  'name': match.group(3) ?? s,
                };
              }
              return {'name': s}; // Default to just name if no quantity/unit
            })
            .toList();
      }
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
