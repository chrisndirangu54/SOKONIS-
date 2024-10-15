import 'package:flutter/material.dart';
import 'package:grocerry/providers/offer_provider.dart';
import 'package:provider/provider.dart';
import '../screens/product_screen.dart'; // Import the ProductScreen

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final offerProvider = Provider.of<OfferProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Offers'),
      ),
      body: FutureBuilder(
        future: offerProvider.fetchOffers(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('An error occurred!'));
          } else {
            return Consumer<OfferProvider>(
              builder: (ctx, offerData, _) {
                return Card(
                  margin: const EdgeInsets.all(16.0), // Margin around the card
                  elevation: 5, // Card shadow elevation
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: offerData.offers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No offers available! Check back later for some great deals! 🎉',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: offerData.offers.length,
                            itemBuilder: (ctx, i) {
                              final offer = offerData.offers[i];
                              return GestureDetector(
                                onTap: () {
                                  // Navigate to the product screen
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProductScreen(
                                          productId: offer.productId),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 8, // Shadow effect
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 15),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    transform: Matrix4.identity()
                                      ..setEntry(
                                          3, 2, 0.001) // Perspective effect
                                      ..rotateX(
                                          0.05), // Slight tilt for 3D effect
                                    child: ListTile(
                                      title: Text(offer.title),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(offer.description),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Original Price: \$${offer.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.red,
                                            ),
                                          ),
                                          Text(
                                            'Discounted Price: \$${offer.discountedPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            8), // Rounded corners for the image
                                        child: Image.network(
                                          offer.imageUrl,
                                          height: 60,
                                          width: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
