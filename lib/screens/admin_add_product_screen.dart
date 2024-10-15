import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart'; // Add this dependency for file picking
import 'package:grocerry/services/product_service.dart'; // Import the ProductService

class AdminAddProductScreen extends StatefulWidget {
  final String? productId; // If null, it means we're adding a new product

  const AdminAddProductScreen({super.key, this.productId});

  @override
  AdminAddProductScreenState createState() => AdminAddProductScreenState();
}

class AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _categoryImageUrlController = TextEditingController();
  final _varietyController = TextEditingController();
  final _varietyImageUrlsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _subcategoriesController = TextEditingController();
  final _subcategoryImageUrlsController = TextEditingController();

  bool _isFresh = false;
  bool _isLocallySourced = false;
  bool _isOrganic = false;
  bool _hasHealthBenefits = false;
  bool _hasDiscounts = false;
  bool _isEcoFriendly = false;
  bool _isSuperfood = false;

  bool _isLoading = false;

  final ProductService _productService =
      ProductService(); // Create ProductService instance

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProductDetails();
    }
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _nameController.text = data?['name'] ?? '';
        _descriptionController.text = data?['description'] ?? '';
        _priceController.text = (data?['price'] ?? '').toString();
        _categoryController.text = data?['category'] ?? '';
        _categoryImageUrlController.text = data?['categoryImageUrl'] ?? '';
        _varietyController.text = data?['variety'] ?? '';
        _varietyImageUrlsController.text =
            (data?['varietyImageUrls'] ?? []).join(',');
        _subcategoriesController.text =
            (data?['subcategories'] ?? []).join(',');
        _subcategoryImageUrlsController.text =
            (data?['subcategoryImageUrls'] ?? []).join(',');
        _imageUrlController.text = data?['pictureUrl'] ?? '';
        _discountedPriceController.text =
            (data?['discountedPrice'] ?? '').toString();

        _isFresh = data?['isFresh'] ?? false;
        _isLocallySourced = data?['isLocallySourced'] ?? false;
        _isOrganic = data?['isOrganic'] ?? false;
        _hasHealthBenefits = data?['hasHealthBenefits'] ?? false;
        _hasDiscounts = data?['hasDiscounts'] ?? false;
        _isEcoFriendly = data?['isEcoFriendly'] ?? false;
        _isSuperfood = data?['isSuperfood'] ?? false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load product details: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      await _productService.addProductsFromCSV(file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Products added from CSV successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected.')),
      );
    }
  }

  void _saveProduct() async {
    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'category': _categoryController.text,
      'categoryImageUrl': _categoryImageUrlController.text,
      'subcategories': _subcategoriesController.text.split(','),
      'subcategoryImageUrls': _subcategoryImageUrlsController.text.split(','),
      'variety': _varietyController.text,
      'varietyImageUrls': _varietyImageUrlsController.text.split(','),
      'pictureUrl': _imageUrlController.text,
      'isFresh': _isFresh,
      'isLocallySourced': _isLocallySourced,
      'isOrganic': _isOrganic,
      'hasHealthBenefits': _hasHealthBenefits,
      'hasDiscounts': _hasDiscounts,
      'discountedPrice':
          double.tryParse(_discountedPriceController.text) ?? 0.0,
      'isEcoFriendly': _isEcoFriendly,
      'isSuperfood': _isSuperfood,
    };

    try {
      if (widget.productId == null) {
        await FirebaseFirestore.instance.collection('products').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
      }

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save product: $e')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _categoryController.clear();
    _categoryImageUrlController.clear();
    _varietyController.clear();
    _varietyImageUrlsController.clear();
    _subcategoriesController.clear();
    _subcategoryImageUrlsController.clear();
    _imageUrlController.clear();
    _discountedPriceController.clear();
    _isFresh = false;
    _isLocallySourced = false;
    _isOrganic = false;
    _hasHealthBenefits = false;
    _hasDiscounts = false;
    _isEcoFriendly = false;
    _isSuperfood = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.productId == null ? 'Add New Product' : 'Edit Product'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Product Name'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Product Description'),
                    ),
                    TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    TextField(
                      controller: _categoryImageUrlController,
                      decoration: const InputDecoration(
                          labelText: 'Category Image URL'),
                    ),
                    TextField(
                      controller: _subcategoriesController,
                      decoration:
                          const InputDecoration(labelText: 'Subcategories'),
                    ),
                    TextField(
                      controller: _subcategoryImageUrlsController,
                      decoration: const InputDecoration(
                          labelText: 'Subcategory Image URLs'),
                    ),
                    TextField(
                      controller: _varietyController,
                      decoration: const InputDecoration(labelText: 'Variety'),
                    ),
                    TextField(
                      controller: _varietyImageUrlsController,
                      decoration: const InputDecoration(
                          labelText: 'Variety Image URLs'),
                    ),
                    TextField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                    ),
                    TextField(
                      controller: _discountedPriceController,
                      decoration:
                          const InputDecoration(labelText: 'Discounted Price'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildCheckbox('Is Fresh', _isFresh, (value) {
                      setState(() {
                        _isFresh = value ?? false;
                      });
                    }),
                    _buildCheckbox('Is Locally Sourced', _isLocallySourced,
                        (value) {
                      setState(() {
                        _isLocallySourced = value ?? false;
                      });
                    }),
                    _buildCheckbox('Is Organic', _isOrganic, (value) {
                      setState(() {
                        _isOrganic = value ?? false;
                      });
                    }),
                    _buildCheckbox('Has Health Benefits', _hasHealthBenefits,
                        (value) {
                      setState(() {
                        _hasHealthBenefits = value ?? false;
                      });
                    }),
                    _buildCheckbox('Has Discounts', _hasDiscounts, (value) {
                      setState(() {
                        _hasDiscounts = value ?? false;
                      });
                    }),
                    _buildCheckbox('Is Eco-Friendly', _isEcoFriendly, (value) {
                      setState(() {
                        _isEcoFriendly = value ?? false;
                      });
                    }),
                    _buildCheckbox('Is Superfood', _isSuperfood, (value) {
                      setState(() {
                        _isSuperfood = value ?? false;
                      });
                    }),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveProduct,
                      child: const Text('Save Product'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _pickAndUploadCSV,
                      child: const Text('Upload CSV'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?)? onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
