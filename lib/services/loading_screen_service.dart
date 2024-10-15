import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:grocerry/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for fetching user data
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoadingScreenService extends StatefulWidget {
  final Function onComplete;
  const LoadingScreenService({super.key, required this.onComplete});

  @override
  LoadingScreenServiceState createState() => LoadingScreenServiceState();
}

class LoadingScreenServiceState extends State<LoadingScreenService>
    with SingleTickerProviderStateMixin {
  String generatedMessage = "Initializing...";
  GlobalKey repaintKey = GlobalKey();

  late AnimationController _controller;
  late Animation<double> _animation;

  bool allStepsFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Set up the animation controller and bouncing effect
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = Tween<double>(begin: -300, end: 0)
        .chain(CurveTween(curve: Curves.bounceOut))
        .animate(_controller);
  }

  Future<void> _initializeApp() async {
    try {
      // Try Firebase Initialization
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      User? user = FirebaseAuth.instance.currentUser;

      /// Fallback in case of failure

      // Try ChatGPT-based personalized message generation
      bool messageGenerated = await _tryGenerateMessage(user);
      if (!messageGenerated) {
        // Fallback: use a default message if ChatGPT or data fetch fails
        generatedMessage =
            user == null ? "Welcome to SOKONI'S!" : "Welcome back, $user!";
        setState(() {});
      }

      // Complete after message generation
      widget.onComplete();
    } catch (e) {
      // Catch all errors and set final failure state
      allStepsFailed = true;
      setState(() {});
      await Future.delayed(const Duration(seconds: 3));
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<bool> _tryGenerateMessage(User? user) async {
    try {
      if (user == null) {
        // New User: Generate a welcome message
        generatedMessage =
            await generateMessageFromChatGPT("Welcome to SOKONI'S!") ??
                "Welcome to SOKONI'S!";
      } else {
        // Returning User: Fetch user data and personalize message
        Map<String, dynamic> userData = await fetchUserData(user.uid);
        String name = userData['name'] ?? user.email ?? "User";
        generatedMessage =
            await generateMessageFromChatGPT("Welcome back, $name!") ??
                "Welcome back, $name!";
      }
      setState(() {});
      return true; // Message generation successful
    } catch (e) {
      // Handle error
      return false; // Message generation failed
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data() as Map<String, dynamic>? ?? {}; // Use safe fallback
    } catch (e) {
      return {}; // Return empty map if fetch fails
    }
  }

  Future<String?> generateMessageFromChatGPT(String prompt) async {
    try {
      String apiKey = 'your_openai_api_key'; // Replace with your API key
      final url = Uri.parse("https://api.openai.com/v1/completions");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "text-davinci-003",
          "prompt": prompt,
          "max_tokens": 100,
        }),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        return responseData['choices'][0]['text'].trim();
      } else {
        // Log error
        print("Failed to generate message: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // Log error
      print("Error generating message: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!allStepsFailed)
            Positioned.fill(
              child: RepaintBoundary(
                key: repaintKey,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Positioned(
                      top: MediaQuery.of(context).size.height / 2 -
                          150 +
                          _animation.value,
                      left: MediaQuery.of(context).size.width / 2 - 150,
                      child: child!,
                    );
                  },
                  child: NeonTextBounce(generatedMessage),
                ),
              ),
            )
          else
            // If all steps failed, fallback to circular loader
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// Widget for Neon Text with bounce effect
class NeonTextBounce extends StatelessWidget {
  final String text;
  const NeonTextBounce(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 30,
        color: Color.fromARGB(255, 152, 243, 33),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
