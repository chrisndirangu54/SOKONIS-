import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:grocerry/services/groupbuy_service.dart';
import 'package:grocerry/services/product_service.dart';
import 'package:grocerry/models/product.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminAddProductScreen extends StatefulWidget {
  final String? productId;

  const AdminAddProductScreen({super.key, this.productId});

  @override
  AdminAddProductScreenState createState() => AdminAddProductScreenState();
}

class AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitsController = TextEditingController();
  final _categoryImageUrlController = TextEditingController();
  final _subcategoriesController = TextEditingController();
  final _subcategoryImageUrlsController = TextEditingController();
  final _pictureUrlController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _complementaryProductIdsController = TextEditingController();
  final _seasonStartController = TextEditingController();
  final _seasonEndController = TextEditingController();
  final _consumptionTimeController = TextEditingController();
  final _weatherController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _groupDiscountController = TextEditingController();
  final _groupSizeController = TextEditingController();
final _genomicAlternativesController = TextEditingController();
  // Variety fields
  final List<Map<String, TextEditingController>> _varietyControllers = [];

  bool _isFresh = false;
  bool _isLocallySourced = false;
  bool _isOrganic = false;
  bool _hasHealthBenefits = false;
  bool _hasDiscounts = false;
  bool _isEcoFriendly = false;
  bool _isSuperfood = false;
  bool _isComplementary = false;
  bool _isSeasonal = false;
  bool _isGroupActive = false;
  final List<Product> _availableProducts = [

  ]; // Replace with your actual product list
  final List<Product> _selectedProducts = [];
  bool _isLoading = false;

  final ProductService _productService = ProductService();
  late final GroupBuyService? groupBuyService; // Define the groupBuyService variable

  @override
  void initState() {
    super.initState();
    _addVarietyField(); // Add initial variety field
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
        _basePriceController.text = (data?['basePrice'] ?? 0.0).toString();
        _categoryController.text = data?['category'] ?? '';
        _unitsController.text = data?['units'] ?? '';
        _categoryImageUrlController.text = data?['categoryImageUrl'] ?? '';
        _subcategoriesController.text = (data?['subcategories'] ?? []).join(', ');
        _subcategoryImageUrlsController.text = (data?['subcategoryImageUrls'] ?? []).join(', ');
        _pictureUrlController.text = data?['pictureUrl'] ?? '';
        _discountedPriceController.text = (data?['discountedPrice'] ?? 0.0).toString();
        _complementaryProductIdsController.text = (data?['complementaryProductIds'] ?? []).join(', ');
        _seasonStartController.text = data?['seasonStart']?.toString() ?? '';
        _seasonEndController.text = data?['seasonEnd']?.toString() ?? '';
        _consumptionTimeController.text = (data?['consumptionTime'] ?? []).join(', ');
        _weatherController.text = (data?['weather'] ?? []).join(', ');
        _minPriceController.text = (data?['minPrice'] ?? 0.0).toString();
        _groupDiscountController.text = (data?['groupDiscount'] ?? 0.0).toString();
        _groupSizeController.text = (data?['groupSize'] ?? 0).toString();

        _isFresh = data?['isFresh'] ?? false;
        _isLocallySourced = data?['isLocallySourced'] ?? false;
        _isOrganic = data?['isOrganic'] ?? false;
        _hasHealthBenefits = data?['hasHealthBenefits'] ?? false;
        _hasDiscounts = data?['hasDiscounts'] ?? false;
        _isEcoFriendly = data?['isEcoFriendly'] ?? false;
        _isSuperfood = data?['isSuperfood'] ?? false;
        _isComplementary = data?['isComplementary'] ?? false;
        _isSeasonal = data?['isSeasonal'] ?? false;
        _isGroupActive = data?['isGroupActive'] ?? false;
_genomicAlternativesController.text = (data?['genomicAlterations'] ?? []).join(', ');
        // Load varieties
        final varieties = data?['varieties'] as List<Variety>? ?? [];
        _varietyControllers.clear();
        for (var varietyData in varieties) {
          final variety = Variety.fromMap(varietyData as Map<String, Variety>);
          _addVarietyField(
            name: variety.name,
            color: variety.color,
            size: variety.size,
            imageUrl: variety.imageUrl,
            price: variety.price.toString(),
            discountedPrice: variety.discountedPrice?.toString() ?? '',
          );
        }
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

  void _addVarietyField({
    String? name,
    String? color,
    String? size,
    String? imageUrl,
    String? price,
    String? discountedPrice,
  }) {
    setState(() {
      _varietyControllers.add({
        'name': TextEditingController(text: name ?? ''),
        'color': TextEditingController(text: color ?? ''),
        'size': TextEditingController(text: size ?? ''),
        'imageUrl': TextEditingController(text: imageUrl ?? ''),
        'price': TextEditingController(text: price ?? ''),
        'discountedPrice': TextEditingController(text: discountedPrice ?? ''),
      });
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
    }
  }

Future<void> _determineProductUsingAI() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Step 1: Gather form data (optional context for all products)
    final productName = _nameController.text.isNotEmpty ? _nameController.text : 'Unnamed Product';
    final varieties = _varietyControllers.map((vc) => {
      'name': vc['name']!.text,
      'color': vc['color']!.text,
      'size': vc['size']!.text,
      'imageUrl': vc['imageUrl']!.text,
      'price': double.tryParse(vc['price']!.text) ?? 0.0,
      'discountedPrice': double.tryParse(vc['discountedPrice']!.text) ?? 0.0,
    }).toList();

    final productData = {
      'name': productName,
      'description': _descriptionController.text,
      'basePrice': double.tryParse(_basePriceController.text) ?? 0.0,
      'category': _categoryController.text,
      'units': _unitsController.text,
      'categoryImageUrl': _categoryImageUrlController.text,
      'subcategories': _subcategoriesController.text.split(', '),
      'subcategoryImageUrls': _subcategoryImageUrlsController.text.split(', '),
      'varieties': varieties,
      'pictureUrl': _pictureUrlController.text,
      'isFresh': _isFresh,
      'isLocallySourced': _isLocallySourced,
      'isOrganic': _isOrganic,
      'hasHealthBenefits': _hasHealthBenefits,
      'hasDiscounts': _hasDiscounts,
      'discountedPrice': double.tryParse(_discountedPriceController.text) ?? 0.0,
      'isEcoFriendly': _isEcoFriendly,
      'isSuperfood': _isSuperfood,
      'complementaryProductIds': _complementaryProductIdsController.text.split(', '),
      'isComplementary': _isComplementary,
      'isSeasonal': _isSeasonal,
      'seasonStart': _seasonStartController.text,
      'seasonEnd': _seasonEndController.text,
      'consumptionTime': _consumptionTimeController.text.split(', '),
      'weather': _weatherController.text.split(', '),
      'minPrice': double.tryParse(_minPriceController.text) ?? 0.0,
      'groupDiscount': double.tryParse(_groupDiscountController.text) ?? 0.0,
      'groupSize': int.tryParse(_groupSizeController.text) ?? 0,
      'isGroupActive': _isGroupActive,
      'genomicAlterations': _genomicAlternativesController.text.split(', '),
    };

    // Step 2: Pick multiple files
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'txt', 'jpg', 'jpeg', 'png'],
      allowMultiple: true, // Allow multiple files
    );

    List<Product> products = [];

    if (result != null && result.files.isNotEmpty) {
      // Step 3: Process each file
      for (var fileEntry in result.files) {
        final filePath = fileEntry.path!;
        final fileType = fileEntry.extension!.toLowerCase();
        final file = File(filePath);

        String? fileContent;
        if (['csv', 'json', 'txt'].contains(fileType)) {
          fileContent = await file.readAsString();
        } else if (['jpg', 'jpeg', 'png'].contains(fileType)) {
          fileContent = base64Encode(await file.readAsBytes());
        }

        // Step 4: Determine product(s) using AI for this file
        List<Product> fileProducts = await _determineProductsUsingAIImplementation(
          productName,
          productData,
          fileContent: fileContent,
          fileType: fileType, 
        );
        products.addAll(fileProducts);
      }
    } else {
      // If no files selected, use form data alone to determine at least one product
      List<Product> formProducts = await _determineProductsUsingAIImplementation(
        productName,
        productData, fileType: '', 
      );
      products.addAll(formProducts);
    }

    if (products.isEmpty) {
      throw Exception('No products determined by AI');
    }

    // Step 5: Save all products to Firestore in a batch
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var product in products) {
      final docRef = FirebaseFirestore.instance.collection('products').doc(product.id);
      batch.set(docRef, product.toMap());
    }
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${products.length} product(s) using AI!')),
    );

    _clearForm();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to determine products with AI: $e')),
    );
  }

  setState(() {
    _isLoading = false;
  });
}


Future<List<Product>> _determineProductsUsingAIImplementation(
  String productName,
  Map<String, dynamic> productData, {
  String? fileContent,
  required String fileType,

}) async {
  final url = Uri.parse('https://api.x.ai/v1/chat/completions'); // Verify endpoint
  String? grokApiKey;
  List<Product>? availableProducts; // Add list of available products

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $grokApiKey',
  };

  // Convert available products to a JSON string for the AI
  final availableProductsJson = jsonEncode(
    availableProducts!.map((p) => {
      'name': p.name,
      'basePrice': p.basePrice,
      'description': p.description,
      'category': p.category,
      // Include other fields as needed
    }).toList(),
  );

  String query =
      'Product: $productName. Data: ${jsonEncode(productData)}. '
      'Available Products: $availableProductsJson. '
      'Please organize this into Product objects with the following structure. '
      'If the product is repeated, convert it into a variety. '
      'For Genomic Alternatives, select relevant products from the Available Products list:\n\n'
      '- **Name**: [String]\n'
      '- **Base Price**: [double]\n'
      '- **Description**: [String]\n'
      '- **Category**: [String]\n'
      '- **Units**: [String]\n'
      '- **Category Image URL**: [String]\n'
      '- **Subcategories**: [List<String>]\n'
      '- **Subcategory Image URLs**: [List<String>]\n'
      '- **Varieties**: [List<Variety>]\n'
      '  - **Name**: [String]\n'
      '  - **Color**: [String]\n'
      '  - **Size**: [String]\n'
      '  - **Image URL**: [String]\n'
      '  - **Price**: [double]\n'
      '  - **Discounted Price**: [double?]\n'
      '- **Picture URL**: [String]\n'
      '- **Is Fresh**: [bool]\n'
      '- **Is Locally Sourced**: [bool]\n'
      '- **Is Organic**: [bool]\n'
      '- **Has Health Benefits**: [bool]\n'
      '- **Has Discounts**: [bool]\n'
      '- **Discounted Price**: [double]\n'
      '- **Is Eco-Friendly**: [bool]\n'
      '- **Is Superfood**: [bool]\n'
      '- **Consumption Time**: [List<String>] // Possible values: lunch, breakfast, supper\n'
      '- **Weather**: [List<String>] // Possible values: rainy, cloudy, sunny, other\n'
      '- **Min Price**: [double?]\n'
      '- **Genomic Alternatives**: [List<Product>] // Select from Available Products\n'
      'Respond in JSON format matching this structure.';

final body = jsonEncode({
  'model': 'grok-beta', // Specify the Grok model you want to use
  'messages': [
    {
      'role': 'system',
      'content': 'You are an AI expert in product data organization.',
    },
    {
      'role': 'user',
      'content': query,
    }
  ],
  'max_tokens': 1000,
});

final response = await http.post(url, headers: headers, body: body);
if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  String jsonContent = data['choices'][0]['message']['content'];

  Map<String, dynamic> productMap = jsonDecode(jsonContent);

  // Assuming fromJson now returns Future<List<Product>>
  List<Product> products = await Product.fromJson(productMap);
  if (products.isNotEmpty) {
    Product product = products[0];

    // Update the discounted price stream with the first product's discounted price
    groupBuyService!.updateDiscountedPrice(product.discountedPrice);

    // Here, we might need to adjust the product's consumption time and weather
    // based on your UI selections, assuming they are stored in controllers
    product.consumptionTime = _consumptionTimeController.text.split(', ');
    product.weather = _weatherController.text.split(', ');
  
    return [product];
  } else {
    throw Exception('No product data was returned');
  }
} else {
  print('Failed to determine product details: ${response.body}');
  throw Exception('Failed to fetch product details from AI');
}}

  void _saveProduct() async {
    try {
      final varieties = _varietyControllers.map((vc) => Variety(
        name: vc['name']!.text,
        color: vc['color']!.text,
        size: vc['size']!.text,
        imageUrl: vc['imageUrl']!.text,
        price: double.tryParse(vc['price']!.text) ?? 0.0,
        discountedPrice: double.tryParse(vc['discountedPrice']!.text) ?? 0.0,
        discountedPriceStream: null, // Stream not set here
      )).toList();

      final productData = Product(
        id: widget.productId ?? FirebaseFirestore.instance.collection('products').doc().id,
        name: _nameController.text,
        basePrice: double.tryParse(_basePriceController.text) ?? 0.0,
        description: _descriptionController.text,
        category: _categoryController.text,
        units: _unitsController.text,
        categoryImageUrl: _categoryImageUrlController.text,
        subcategories: _subcategoriesController.text.split(', '),
        subcategoryImageUrls: _subcategoryImageUrlsController.text.split(', '),
        varieties: varieties,
        pictureUrl: _pictureUrlController.text,
        isComplementary: _isComplementary,
        complementaryProductIds: _complementaryProductIdsController.text.split(', '),
        isSeasonal: _isSeasonal,
        seasonStart: DateTime.tryParse(_seasonStartController.text),
        seasonEnd: DateTime.tryParse(_seasonEndController.text),
        isFresh: _isFresh,
        isLocallySourced: _isLocallySourced,
        isOrganic: _isOrganic,
        hasHealthBenefits: _hasHealthBenefits,
        hasDiscounts: _hasDiscounts,
        discountedPrice: double.tryParse(_discountedPriceController.text) ?? 0.0,
        isEcoFriendly: _isEcoFriendly,
        isSuperfood: _isSuperfood,
        consumptionTime: _consumptionTimeController.text.split(', '),
        weather: _weatherController.text.split(', '),
        minPrice: double.tryParse(_minPriceController.text) ?? 0.0,
        groupDiscount: double.tryParse(_groupDiscountController.text) ?? 0.0,
        groupSize: int.tryParse(_groupSizeController.text) ?? 0,
        isGroupActive: _isGroupActive,
        rating: 0, 
        genomicAlternatives:    _getGenomicAlternatives()
      );

      if (widget.productId == null) {
        await FirebaseFirestore.instance.collection('products').doc(productData.id).set(productData.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
      } else {
        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update(productData.toMap());
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
    _basePriceController.clear();
    _categoryController.clear();
    _unitsController.clear();
    _categoryImageUrlController.clear();
    _subcategoriesController.clear();
    _subcategoryImageUrlsController.clear();
    _pictureUrlController.clear();
    _discountedPriceController.clear();
    _complementaryProductIdsController.clear();
    _seasonStartController.clear();
    _seasonEndController.clear();
    _consumptionTimeController.clear();
    _weatherController.clear();
    _minPriceController.clear();
    _groupDiscountController.clear();
    _groupSizeController.clear();
    for (var vc in _varietyControllers) {
      for (var controller in vc.values) {
        controller.clear();
      }
    }
    _varietyControllers.clear();
    _addVarietyField();
    _isFresh = false;
    _isLocallySourced = false;
    _isOrganic = false;
    _hasHealthBenefits = false;
    _hasDiscounts = false;
    _isEcoFriendly = false;
    _isSuperfood = false;
    _isComplementary = false;
    _isSeasonal = false;
    _isGroupActive = false;
    _genomicAlternativesController.clear();
  }
List<Product> _getGenomicAlternatives() {
    final productNames = _genomicAlternativesController.text.split(', ');
    return productNames
        .map((name) => _availableProducts.firstWhere(
              (product) => product.name == name,
              orElse: () => Product(name: name, id: '', units: '', basePrice: 0.0, description: '', category: '', categoryImageUrl: '', pictureUrl: '', discountedPrice: 0.0), // Fallback if not found
            ))
        .toList();
  }
  void _showAddOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Product Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndUploadCSV();
                },
                child: const Text('Upload from CSV'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _determineProductUsingAI();
                },
                child: const Text('Determine with AI'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  // Predefined values for Consumption Time and Weather
  final List<String> consumptionTimeOptions = ['lunch', 'breakfast', 'supper'];
  final List<String> weatherOptions = ['rainy', 'cloudy', 'sunny', 'other'];

  // State variables to hold selected values
  List<String> selectedConsumptionTimes = _consumptionTimeController.text.isNotEmpty
      ? _consumptionTimeController.text.split(',').map((s) => s.trim()).toList()
      : [];
  List<String> selectedWeather = _weatherController.text.isNotEmpty
      ? _weatherController.text.split(',').map((s) => s.trim()).toList()
      : [];

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.productId == null ? 'Add New Product' : 'Edit Product'),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                  TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                  TextField(
                      controller: _basePriceController,
                      decoration: const InputDecoration(labelText: 'Base Price'),
                      keyboardType: TextInputType.number),
                  TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category')),
                  TextField(controller: _unitsController, decoration: const InputDecoration(labelText: 'Units')),
                  TextField(controller: _categoryImageUrlController, decoration: const InputDecoration(labelText: 'Category Image URL')),
                  TextField(controller: _subcategoriesController, decoration: const InputDecoration(labelText: 'Subcategories (comma-separated)')),
                  TextField(
                      controller: _subcategoryImageUrlsController,
                      decoration: const InputDecoration(labelText: 'Subcategory Image URLs (comma-separated)')),
                  TextField(controller: _pictureUrlController, decoration: const InputDecoration(labelText: 'Picture URL')),
                  TextField(
                      controller: _discountedPriceController,
                      decoration: const InputDecoration(labelText: 'Discounted Price'),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: _complementaryProductIdsController,
                      decoration: const InputDecoration(labelText: 'Complementary Product IDs (comma-separated)')),
                  // Season Start Date Picker
                  TextField(
                    controller: _seasonStartController,
                    decoration: const InputDecoration(
                      labelText: 'Season Start (YYYY-MM-DD)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _seasonStartController),
                  ),
                  // Season End Date Picker
                  TextField(
                    controller: _seasonEndController,
                    decoration: const InputDecoration(
                      labelText: 'Season End (YYYY-MM-DD)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _seasonEndController),
                  ),
                  // Consumption Time multi-select
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Consumption Time', style: TextStyle(fontSize: 16)),
                        Wrap(
                          spacing: 8.0,
                          children: consumptionTimeOptions.map((option) {
                            return FilterChip(
                              label: Text(option),
                              selected: selectedConsumptionTimes.contains(option),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedConsumptionTimes.add(option);
                                  } else {
                                    selectedConsumptionTimes.remove(option);
                                  }
                                  _consumptionTimeController.text = selectedConsumptionTimes.join(', ');
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Weather multi-select
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Weather', style: TextStyle(fontSize: 16)),
                        Wrap(
                          spacing: 8.0,
                          children: weatherOptions.map((option) {
                            return FilterChip(
                              label: Text(option),
                              selected: selectedWeather.contains(option),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedWeather.add(option);
                                  } else {
                                    selectedWeather.remove(option);
                                  }
                                  _weatherController.text = selectedWeather.join(', ');
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                      controller: _minPriceController,
                      decoration: const InputDecoration(labelText: 'Min Price'),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: _groupDiscountController,
                      decoration: const InputDecoration(labelText: 'Group Discount'),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: _groupSizeController,
                      decoration: const InputDecoration(labelText: 'Group Size'),
                      keyboardType: TextInputType.number),

                  const SizedBox(height: 20),
                  Text('Varieties', style: Theme.of(context).textTheme.headlineSmall),
                  ..._varietyControllers.map((vc) => Column(
                        children: [
                          TextField(controller: vc['name'], decoration: const InputDecoration(labelText: 'Variety Name')),
                          TextField(controller: vc['color'], decoration: const InputDecoration(labelText: 'Variety Color')),
                          TextField(controller: vc['size'], decoration: const InputDecoration(labelText: 'Variety Size')),
                          TextField(controller: vc['imageUrl'], decoration: const InputDecoration(labelText: 'Variety Image URL')),
                          TextField(
                              controller: vc['price'],
                              decoration: const InputDecoration(labelText: 'Variety Price'),
                              keyboardType: TextInputType.number),
                          TextField(
                              controller: vc['discountedPrice'],
                              decoration: const InputDecoration(labelText: 'Variety Discounted Price'),
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 10),
                        ],
                      )),
                  ElevatedButton(
                    onPressed: () => _addVarietyField(),
                    child: const Text('Add Another Variety'),
                  ),
TextField(
          controller: _genomicAlternativesController,
          decoration: InputDecoration(
            labelText: 'Genomic Alternatives (comma-separated)',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showProductSelectionDialog,
            ),
          ),
          readOnly: true, // Prevents manual editing
          onTap: _showProductSelectionDialog, // Opens dialog on tap
        ),

                  const SizedBox(height: 20),
                  _buildCheckbox('Is Fresh', _isFresh, (value) => setState(() => _isFresh = value ?? false)),
                  _buildCheckbox('Is Locally Sourced', _isLocallySourced, (value) => setState(() => _isLocallySourced = value ?? false)),
                  _buildCheckbox('Is Organic', _isOrganic, (value) => setState(() => _isOrganic = value ?? false)),
                  _buildCheckbox('Has Health Benefits', _hasHealthBenefits, (value) => setState(() => _hasHealthBenefits = value ?? false)),
                  _buildCheckbox('Has Discounts', _hasDiscounts, (value) => setState(() => _hasDiscounts = value ?? false)),
                  _buildCheckbox('Is Eco-Friendly', _isEcoFriendly, (value) => setState(() => _isEcoFriendly = value ?? false)),
                  _buildCheckbox('Is Superfood', _isSuperfood, (value) => setState(() => _isSuperfood = value ?? false)),
                  _buildCheckbox('Is Complementary', _isComplementary, (value) => setState(() => _isComplementary = value ?? false)),
                  _buildCheckbox('Is Seasonal', _isSeasonal, (value) => setState(() => _isSeasonal = value ?? false)),
                  _buildCheckbox('Is Group Active', _isGroupActive, (value) => setState(() => _isGroupActive = value ?? false)),

                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _saveProduct, child: const Text('Save Product')),
                  ElevatedButton(onPressed: _showAddOptionsDialog, child: const Text('Add Product Options')),
                ],
              ),
            ),
          ),
  );
}

// Helper method to show date picker and update controller
Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
  );
  if (picked != null) {
    setState(() {
      controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }
}
  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Products'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  children: _availableProducts.map((product) {
                    final isSelected = _selectedProducts.contains(product);
                    return FilterChip(
                      label: Text(product.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedProducts.add(product);
                          } else {
                            _selectedProducts.remove(product);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _genomicAlternativesController.text = _selectedProducts.join(', ');
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

Widget _buildCheckbox(String label, bool value, Function(bool?)? onChanged) {
  return CheckboxListTile(
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}}