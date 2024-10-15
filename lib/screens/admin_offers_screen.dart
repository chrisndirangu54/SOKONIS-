import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore package
import '../models/offer.dart';
import '../providers/offer_provider.dart';
import 'package:provider/provider.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  AdminOffersScreenState createState() => AdminOffersScreenState();
}

class AdminOffersScreenState extends State<AdminOffersScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  late double _price;
  late double _discountedPrice;
  late String _selectedProductId; // Product ID field
  late String _imageUrl; // Automatically set from selected product
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // Fetch products from Firestore
  Future<List<QueryDocumentSnapshot>> _fetchProducts() async {
    final productsSnapshot =
        await FirebaseFirestore.instance.collection('products').get();
    return productsSnapshot.docs;
  }

  // Save the offer and update the product price in Firestore
  Future<void> _saveOffer(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newOffer = Offer(
        id: '', // Backend or Firestore will generate this
        title: _title,
        description: _description,
        imageUrl: _imageUrl, // Set image URL from the selected product
        startDate: _startDate,
        endDate: _endDate,
        price: _price,
        productId: _selectedProductId, // Use selected product ID
        discountedPrice: _discountedPrice,
      );

      // Add offer using OfferProvider
      context.read<OfferProvider>().addOffer(newOffer);

      // Update product price in Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(_selectedProductId)
          .update({'discountedPrice': _discountedPrice});

      Navigator.of(context).pop(); // Close the dialog
    }
  }

  void _deleteOffer(BuildContext context, String offerId) {
    context.read<OfferProvider>().deleteOffer(offerId);
  }

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<OfferProvider>().offers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Add New Offer'),
                  content: Form(
                    key: _formKey,
                    child: FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _fetchProducts(),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No products available'));
                        }

                        final products = snapshot.data!;

                        return SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                decoration:
                                    const InputDecoration(labelText: 'Title'),
                                onSaved: (value) => _title = value!,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a title';
                                  }
                                  return null;
                                },
                              ),
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Description'),
                                onSaved: (value) => _description = value!,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a description';
                                  }
                                  return null;
                                },
                              ),
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Discounted Price'),
                                keyboardType: TextInputType.number,
                                onSaved: (value) =>
                                    _discountedPrice = double.parse(value!),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a discounted price';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                              DropdownButtonFormField<String>(
                                value: _selectedProductId,
                                hint: const Text('Select Product'),
                                items: products.map((product) {
                                  return DropdownMenuItem<String>(
                                    value: product.id,
                                    child: Text(product['title']),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedProductId = value!;
                                    // Set the image URL from the selected product
                                    _imageUrl = products.firstWhere(
                                        (prod) => prod.id == value)['imageUrl'];
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a product';
                                  }
                                  return null;
                                },
                              ),
                              TextButton(
                                onPressed: () async {
                                  _startDate = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      ) ??
                                      _startDate;
                                  setState(() {}); // Refresh UI
                                },
                                child: Text(
                                    'Start Date: ${_startDate.toLocal()}'
                                        .split(' ')[0]),
                              ),
                              TextButton(
                                onPressed: () async {
                                  _endDate = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      ) ??
                                      _endDate;
                                  setState(() {}); // Refresh UI
                                },
                                child: Text('End Date: ${_endDate.toLocal()}'
                                    .split(' ')[0]),
                              ),
                              ElevatedButton(
                                onPressed: () => _saveOffer(context),
                                child: const Text('Save Offer'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: offers.length,
        itemBuilder: (ctx, i) => ProductTile(
          offer: offers[i],
          onDelete: () => _deleteOffer(context, offers[i].id),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _deleteOffer(context, offers[i].id);
            },
          ),
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Offer offer;
  final VoidCallback? onDelete;

  const ProductTile(
      {super.key,
      required this.offer,
      this.onDelete,
      required IconButton trailing});

  @override
  Widget build(BuildContext context) {
    double discountPercentage =
        ((offer.price - offer.discountedPrice) / offer.price) * 100;

    return ListTile(
      title: Text(offer.title),
      subtitle: Text(offer.description),
      leading: Stack(
        children: <Widget>[
          // Product Image
          Image.network(offer.imageUrl,
              height: 100, width: 100, fit: BoxFit.cover),
          // Discount Percentage Badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '-${discountPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
