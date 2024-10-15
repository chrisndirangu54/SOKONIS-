import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews'));
          } else if (!snapshot.hasData || snapshot.data?.docs.isEmpty == true) {
            return const Center(child: Text('No reviews found'));
          } else {
            final reviews = snapshot.data?.docs ?? [];

            return ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final reviewData =
                    reviews[index].data() as Map<String, dynamic>;
                final reviewerName = reviewData['reviewerName'] ?? 'Anonymous';
                final reviewText = reviewData['reviewText'] ?? '';
                final rating = reviewData['rating'] ?? 0;
                final reviewDate =
                    (reviewData['reviewDate'] as Timestamp?)?.toDate();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade300,
                    child: Text(
                      reviewerName.isNotEmpty
                          ? reviewerName[0].toUpperCase()
                          : '?', // Handle case where reviewerName might be empty
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(reviewerName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(reviewText),
                      const SizedBox(height: 5),
                      Row(
                        children: List.generate(
                          5,
                          (starIndex) => Icon(
                            Icons.star,
                            color: starIndex < rating
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (reviewDate != null)
                        Text(
                          'Reviewed on ${reviewDate.toLocal()}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
