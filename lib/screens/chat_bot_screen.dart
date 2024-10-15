import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:grocerry/providers/cart_provider.dart'; // For cart functionality

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  late String selectedVariety; // Define a default value or initialize as needed

  late User user;
  late CartProvider cartProvider;

  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  List<String> _firestoreProductNames =
      []; // List to store Firestore product names
  bool _isLoading = false;

  get quantity => null;

  @override
  void initState() {
    super.initState();
    cartProvider = Provider.of<CartProvider>(context, listen: false);

    _fetchAllProductNames(); // Fetch all product names on initialization
  }

  Future<void> _fetchAllProductNames() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('products').get();

    setState(() {
      _firestoreProductNames =
          snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  final List<Map<String, String>> _conversationHistory = [];

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add("You: $message");
      _conversationHistory.add({"role": "user", "content": message});
    });

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Store message with sentiment
    double sentimentScore = await _getSentimentScore(message);
    _storeConversationToFirestore(message, sentimentScore, "user");

    // Process the message with ChatGPT, passing the conversation history
    var response = await _processMessageWithChatGPT(_conversationHistory);
    setState(() {
      _messages.add("Bellamy: $response");
      _isLoading = false; // Hide loading indicator
    });

    // Store chatbot response
    sentimentScore = await _getSentimentScore(response);
    _storeConversationToFirestore(response, sentimentScore, "bot");
  }

  // Store conversation to Firestore
  Future<void> _storeConversationToFirestore(
      String message, double sentimentScore, String sender) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('conversations').add({
      'message': message,
      'sentimentScore': sentimentScore,
      'sender': sender,
      'timestamp': Timestamp.now(),
      'userId': user.id, // Assuming user id is available
    });
  }

  Future<double> _getSentimentScore(String text) async {
    const String apiKey = "YOUR_GOOGLE_CLOUD_API_KEY";
    final response = await http.post(
      Uri.parse(
          'https://language.googleapis.com/v1/documents:analyzeSentiment?key=$apiKey'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "document": {"type": "PLAIN_TEXT", "content": text},
        "encodingType": "UTF8"
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      double sentimentScore = data['documentSentiment']['score'];
      return sentimentScore;
    } else {
      return 0.0; // Default score in case of error
    }
  }

  Future<String> _processMessageWithChatGPT(
      List<Map<String, String>> conversationHistory) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": conversationHistory,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String chatbotResponse = data['choices'][0]['message']['content'];

      if (chatbotResponse.contains('Sorry') || chatbotResponse.length < 10) {
        // First, give an explanation
        setState(() {
          _messages.add(
              "Bellamy: I'm having trouble answering that question. Let me redirect you to the Technical Support Team for further assistance.");
        });

        // Then, trigger the WhatsApp redirection
        _openWhatsApp();
        return "Redirecting you to the Technical Support Team for further assistance...";
      } else {
        return chatbotResponse;
      }
    } else {
      return "I'm unable to process your request at the moment. Let me redirect you to Technical Support Team for help.";
    }
  }

  void _openWhatsApp() async {
    const String phoneNumber = '+254705635198';
    const String message = 'Hello! I have a query about your products.';
    final Uri uri = Uri.parse('https://wa.me/$phoneNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  Future<void> _processImageWithOCR(String imagePath) async {
    var extractedText = await _performOCR(imagePath);
    await _sendMessage(extractedText!);

    var recognizedProducts = await _recognizeProducts(imagePath);
    for (var product in recognizedProducts) {
      await _processProduct(product, selectedVariety, quantity);
    }
  }

  Future<String?> _performOCR(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return recognizedText.text.isNotEmpty
          ? recognizedText.text
          : "No text found.";
    } catch (e) {
      print("Error performing OCR: $e");
      return "Error extracting text from image.";
    } finally {
      textRecognizer.close();
    }
  }

  Future<List<String>> _recognizeProducts(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single, // Corrected to use DetectionMode.single
      classifyObjects: true,
      multipleObjects: true,
    );
    final objectDetector = ObjectDetector(options: options);

    try {
      final List<DetectedObject> detectedObjects =
          await objectDetector.processImage(inputImage);
      List<String> recognizedProducts = [];

      for (DetectedObject detectedObject in detectedObjects) {
        for (Label label in detectedObject.labels) {
          recognizedProducts.add(label.text);
        }
      }

      return recognizedProducts.isNotEmpty
          ? recognizedProducts
          : ["No products recognized."];
    } catch (e) {
      print("Error performing object recognition: $e");
      return ["Error recognizing products."];
    } finally {
      objectDetector.close();
    }
  }

  Future<void> _processProduct(
      String product, String selectedVariety, dynamic quantity) async {
    String? englishProductName = await _convertToEnglish(product);
    if (englishProductName != null) {
      var match = await _compareWithFirestore(englishProductName);
      if (match != null) {
        // Call to add the item to the cart
        cartProvider.addItem(
            match as Product, user, selectedVariety as Variety?, quantity);

        // Send message and show toast
        await _sendMessage("Added $match to your cart.");
        Fluttertoast.showToast(
            msg: "$match added to your cart.", toastLength: Toast.LENGTH_SHORT);
      } else {
        await _sendMessage("No matching product found for: $product");
      }
    } else {
      await _sendMessage("Could not convert product name to English.");
    }
  }

  Future<String?> _convertToEnglish(String productName) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content": "Translate the product name '$productName' to English."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return null;
    }
  }

  Future<String?> _compareWithFirestore(String productName) async {
    final suggestions = await _getSuggestionsFromChatGPT(productName);

    if (suggestions != null && suggestions.isNotEmpty) {
      for (String suggestion in suggestions) {
        String? matchedProduct = _firestoreProductNames.firstWhere(
          (name) => _isProductMatch(name, suggestion),
          orElse: () => '',
        );
        if (matchedProduct != null) {
          return matchedProduct;
        }
      }
    }
    return null;
  }

  Future<List<String>?> _getSuggestionsFromChatGPT(String productName) async {
    const String apiKey = "YOUR_CHATGPT_API_KEY";
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content":
                "What are some similar product names or possible corrections for the name '$productName'? Include synonyms and common typos."
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(
          data['choices'][0]['message']['content'].split(','));
    } else {
      print("Error fetching suggestions from ChatGPT: ${response.body}");
      return null;
    }
  }

  bool _isProductMatch(String firestoreProductName, String userInput) {
    return firestoreProductName.toLowerCase() == userInput.toLowerCase();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      await _processImageWithOCR(pickedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Chatbot - Bellamy"),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _pickImage,
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUserMessage = message.startsWith("You:");

                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUserMessage ? Colors.blue[200] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isUserMessage ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ]));
  }
}
