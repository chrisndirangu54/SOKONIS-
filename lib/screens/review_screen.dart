import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add for date formatting

class ReviewScreen extends StatelessWidget {
  final String productId;

  const ReviewScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Reviews'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .collection('reviews')
            .orderBy('reviewDate', descending: true) // Sort by date
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading reviews: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reviews found'));
          }

          final reviews = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final reviewData = reviews[index].data() as Map<String, dynamic>;
              final reviewerName =
                  reviewData['reviewerName'] as String? ?? 'Anonymous';
              final reviewText = reviewData['reviewText'] as String? ?? '';
              final rating = (reviewData['rating'] as num?)?.toInt() ?? 0;
              final reviewDate =
                  (reviewData['reviewDate'] as Timestamp?)?.toDate();
              final autoResponse = reviewData['autoResponse'] as String? ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade300,
                    child: Text(
                      reviewerName.isNotEmpty
                          ? reviewerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(reviewerName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        reviewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: List.generate(
                          5,
                          (starIndex) => Icon(
                            Icons.star,
                            size: 20,
                            color: starIndex < rating
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (reviewDate != null)
                        Text(
                          'Reviewed on ${DateFormat.yMMMd().format(reviewDate)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (autoResponse.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Response: $autoResponse',
                            style: const TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
