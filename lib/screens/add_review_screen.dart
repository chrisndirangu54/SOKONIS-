import 'package:grocerry/models/user.dart' as model;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // For API calls
import 'dart:convert';

class AddReviewScreen extends StatefulWidget {
  final String productId;

  const AddReviewScreen({
    super.key,
    required this.productId,
  });

  @override
  AddReviewScreenState createState() => AddReviewScreenState();
}

class AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;

  // Simulated ChatGPT-like API call for sentiment analysis and validity
  Future<Map<String, dynamic>> _analyzeReview(String reviewText) async {
    // Replace with actual API endpoint (e.g., OpenAI)
    const String apiUrl = 'YOUR_API_ENDPOINT';
    const String apiKey = 'YOUR_API_KEY';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'prompt':
            'Analyze the sentiment (positive, negative, neutral) and validity (valid, invalid) of this review: "$reviewText"',
        'max_tokens': 100,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Simulated response parsing
      return {
        'sentiment': data['sentiment'] ??
            'neutral', // e.g., "positive", "negative", "neutral"
        'validity': data['validity'] ?? 'valid', // e.g., "valid", "invalid"
      };
    } else {
      throw Exception('Failed to analyze review');
    }
  }

  // Simulated auto-response generation
  Future<String> _generateResponse(String reviewText, String sentiment) async {
    // Replace with actual API call
    const String apiUrl = 'YOUR_API_ENDPOINT';
    const String apiKey = 'YOUR_API_KEY';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'prompt':
            'Generate a polite response to this $sentiment review: "$reviewText"',
        'max_tokens': 50,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] ?? 'Thank you for your feedback!';
    } else {
      return 'Thank you for your feedback!';
    }
  }

  String _censorName(String name) {
    if (name.length <= 2) return name;
    return name[0] + '*' * (name.length - 2) + name[name.length - 1];
  }

  Future<void> _submitReview() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final model.User? user =
            FirebaseAuth.instance.currentUser as model.User?;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to submit a review')),
          );
          return;
        }

        String userName = (user.name ?? 'Anonymous');
        final String censoredName = _censorName(userName);

        // Analyze sentiment and validity
        final analysis = await _analyzeReview(_reviewController.text);
        final String sentiment = analysis['sentiment'];
        final String validity = analysis['validity'];

        // Generate auto-response
        final String autoResponse =
            await _generateResponse(_reviewController.text, sentiment);

        // Prepare review data with sentiment and validity
        final reviewData = {
          'reviewerName': censoredName,
          'reviewText': _reviewController.text,
          'rating': _rating,
          'reviewDate': Timestamp.now(),
          'sentiment': sentiment,
          'validity': validity,
          'autoResponse': autoResponse,
        };

        final reviewRef = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('reviews')
            .add(reviewData);

        await _updateReviewCount(reviewRef.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateReviewCount(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'reviewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Failed to update review count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Review')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Leave your review', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your review'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text('Rating', style: TextStyle(fontSize: 18)),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                    ),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
