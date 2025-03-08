import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RecipeService {
  final String apiKey =
      'your_openai_api_key'; // Replace with your OpenAI API key

  Future<List<String>> getRecipesByPantryItems(List<String> orderItems, {required int numberOfPeople}) async {
    final prompt =
        'Suggest some recipes based on the following ingredients: ${orderItems.join(', ')}';

    return await _fetchRecipes(prompt);
  }

  Future<List<String>> getUserSuggestedMeals(
      List<String> userSuggestions, {required int numberOfPeople}) async {
    final prompt =
        'Suggest some meals based on the following user suggestions: ${userSuggestions.join(', ')}';

    return await _fetchRecipes(prompt);
  }

  Future<List<String>> getRandomMeal({required int numberOfPeople}) async {
    const prompt = 'Suggest a random meal for dinner.';

    return await _fetchRecipes(prompt);
  }

  Future<List<String>> _fetchRecipes(String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo', // You can use 'gpt-4' if you have access
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens':
              100, // Adjust based on how detailed you want the response
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipes = data['choices'][0]['message']['content'] as String;

        // Split the response into individual recipe suggestions, if they are listed
        return recipes.split('\n').map((recipe) => recipe.trim()).toList();
      } else {
        throw Exception('Failed to fetch recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching recipes: $e');
    }
  }
}

// Recipe model
class Recipe {
  final String id;
  final String name;
  final List<String> ingredients;

  Recipe({required this.id, required this.name, required this.ingredients});

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    return Recipe(
      id: doc.id,
      name: doc['name'],
      ingredients: List<String>.from(doc['ingredients']),
    );
  }
}
