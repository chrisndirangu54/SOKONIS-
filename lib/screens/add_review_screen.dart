import 'package:grocerry/models/user.dart' as model;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Function to censor the name
  String _censorName(String name) {
    if (name.length <= 2) {
      return name; // Return the name as-is if it's too short to censor
    }
    return name[0] + '*' * (name.length - 2) + name[name.length - 1];
  }

  // Function to submit the review
  Future<void> _submitReview() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Get the current user
        final model.User? user =
            FirebaseAuth.instance.currentUser as model.User?;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to submit a review')),
          );
          return;
        }

        // Get user's display name or email
        String? userName = (user.name ?? 'Anonymous');

        // Censor the user's name
        final String censoredName = _censorName(userName!);

        // Prepare review data
        final reviewData = {
          'reviewerName': censoredName,
          'reviewText': _reviewController.text,
          'rating': _rating,
          'reviewDate': Timestamp.now(),
        };

        // Submit the review
        final reviewRef = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('reviews')
            .add(reviewData);

        // Update the review count
        await _updateReviewCount(reviewRef.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );

        Navigator.of(context).pop(); // Go back to the previous screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review')),
        );
      }
    }
  }

  // New method to update review count
  Future<void> _updateReviewCount(String reviewId) async {
    try {
      // Increment the review count for the product
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'reviewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Failed to update review count: $e');
      // Optionally, show an error message to the user if updating fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Review'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leave your review',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your review';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Rating',
                style: TextStyle(fontSize: 18),
              ),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _submitReview,
                  child: const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}