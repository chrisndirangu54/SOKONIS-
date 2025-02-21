import 'dart:async';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart'; // Import ModelViewer
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart'; // Import the uni_links package
// For gestures

import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, String? link});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool? _isLoading = false;
  bool? _passwordVisible = false;
  String? _passwordStrength = '';
  String? _referralCode; // Store the referral code
  late String _countryCode = '+254'; // Default country code

  late AnimationController _controller;
  late StreamSubscription _linkSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.repeat(reverse: true);

    // Listen for incoming links
    _linkSubscription = linkStream.listen((String? link) {
      if (link != null) {
        _parseReferralCode(link);
      }
    }, onError: (err) {
      print("Error listening for links: $err");
    });
  }

  void _parseReferralCode(String link) {
    Uri uri = Uri.parse(link);
    setState(() {
      _referralCode = uri.queryParameters['ref']; // Extract referral code
    });
    print('Referral Code: $_referralCode'); // For debugging
  }

  @override
  void dispose() {
    _linkSubscription.cancel(); // Cancel the subscription
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) => _controller.reverse(),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2), // Shadow color
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(
                          0, 4), // Shadow position (horizontal, vertical)
                    ),
                  ],
                ),
                child: GlassmorphicContainer(
                  width: 120,
                  height: 120,
                  borderRadius: 20,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.1)
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final tiltValue = 0.02 *
                          Curves.elasticInOut.transform(_controller.value);
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002) // Perspective for 3D depth
                          ..rotateY(tiltValue)
                          ..rotateX(tiltValue),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/basket.png',
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const Text('Register'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            color: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          height: 300, // Set the height of the 3D model
                          width: 300, // Set the width of the 3D model
                          child: ModelViewer(
                            src:
                                'assets/3d/basket.gltf', // Path to your 3D model (GLTF or GLB format)
                            alt: "A 3D model of a basket",
                            autoRotate: _isLoading, // Auto-rotate when loading
                            cameraControls:
                                !_isLoading!, // Disable camera controls when loading
                            disablePan:
                                _isLoading, // Disable panning when loading
                            disableZoom:
                                _isLoading, // Disable zooming when loading
                            autoRotateDelay:
                                0, // Start rotating immediately when loading
                            cameraOrbit: _isLoading!
                                ? "0deg 90deg 2.5m"
                                : "0deg 0deg 2.5m", // Define camera angle
                          )),

                      const SizedBox(height: 20),

                      // Welcome Text
                      Text(
                        'Create an Account',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Email & Contact TextFormField (unchanged)
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your email' : null,
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: CountryCodePicker(
                              onChanged: (code) {
                                setState(() {
                                  _countryCode = code.dialCode ?? '+1';
                                });
                              },
                              // Initial selection and favorite countries can be customized here
                              initialSelection: 'Kenya',
                              favorite: const ['+254', 'Kenya'],
                              // Optional. Shows only country name and flag
                              showCountryOnly: false,
                              // Optional. Shows only country name and flag when popup is closed.
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _contactController,
                              decoration: const InputDecoration(
                                  labelText: 'Contact Number'),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your contact number';
                                }
                                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Full Name'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Password TextFormField with toggle visibility
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible!
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: _passwordVisible!
                                  ? Colors.orange
                                  : Colors.black,
                            ),
                            onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible!),
                          ),
                        ),
                        obscureText: !_passwordVisible!,
                        validator: (value) => value!.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                        onChanged: (value) => setState(() {
                          _passwordStrength = _getPasswordStrength(value);
                        }),
                      ),

                      // Password Strength Indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: _passwordStrength!.substring(0,
                                    2), // Assuming the first two characters are the emoji
                                style: TextStyle(
                                    color: _getPasswordStrengthColor(
                                        _passwordStrength!)),
                              ),
                              TextSpan(
                                text: _passwordStrength!.substring(
                                    2), // The rest of the text after the emoji
                                style: const TextStyle(
                                    color: Colors
                                        .black), // Or any color you prefer for the text part
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16.0),
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _isLoading!
                                  ? Colors.orange.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.2),
                              spreadRadius: 5,
                              blurRadius: 15,
                              offset: const Offset(0, 3), // Shadow position
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTapDown: (_) => setState(() {
                            _controller.forward(); // Animate on press
                          }),
                          onTapUp: (_) => setState(() {
                            _controller
                                .reverse(); // Return to normal state on release
                            _handleRegistration(); // Trigger registration after release
                          }),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final tiltValue = 0.03 *
                                  _controller
                                      .value; // Slight tilt for 3D effect
                              final scaleValue = 1 -
                                  _controller.value *
                                      0.1; // Scale down when pressed

                              return Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.002) // Perspective effect
                                  ..rotateX(tiltValue) // 3D tilt on X-axis
                                  ..rotateY(tiltValue) // 3D tilt on Y-axis
                                  ..scale(scaleValue), // Scale the button
                                alignment: Alignment.center,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading! ? null : _handleRegistration,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 50, vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50.0),
                                    ),
                                    elevation: 7,
                                    shadowColor: Colors.grey[700],
                                    side: const BorderSide(
                                        color: Colors.blue, width: 1),
                                  ),
                                  child: _isLoading!
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ScaleTransition(
                                              scale: Tween<double>(
                                                begin: 0.7,
                                                end: 1.0,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: AnimationController(
                                                      vsync: this,
                                                      duration: const Duration(
                                                          seconds: 2))
                                                    ..repeat(reverse: true),
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.orange
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                            ),
                                            const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.orange),
                                              strokeWidth: 3.0,
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blue,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTapDown: (_) => _controller.forward(), // Start scaling down
        onTapUp: (_) => _controller.reverse(), // Scale back up
        onTapCancel: () =>
            _controller.reverse(), // Scale back up if tap canceled
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Scale the button based on the controller value
            final scale = 1 - (_controller.value * 0.1); // Scale down by 10%

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Set perspective
                ..scale(scale), // Apply scaling
              alignment: Alignment.center,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  setState(() {
                    _isLoading = true; // Start loading indicator
                  });

                  try {
                    await Provider.of<AuthProvider>(context, listen: false)
                        .signInWithGoogle(_referralCode); // Pass referral code

                    if (Provider.of<AuthProvider>(context, listen: false)
                        .isLoggedIn()) {
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Google sign-in failed')),
                        );
                      }
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google sign-in failed')),
                      );
                    }
                  } finally {
                    setState(() {
                      _isLoading = false; // Stop loading indicator
                    });
                  }
                },
                label: const Text('Login with Google'),
                icon: const Icon(Icons.g_mobiledata_rounded),
              ),
            );
          },
        ),
      ),
    );
  }

  // You keep the existing _getPasswordStrengthColor function as is:
  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case '❤️ Empty':
        return Colors.grey;
      case '💔 Weak':
        return Colors.red;
      case '🖤 Very Weak':
        return Colors.black;
      case '❤️ Weak':
        return Colors.red;
      case '💛 Medium':
        return Colors.yellow;
      case '💚 Strong':
        return Colors.green;
      case '💙 Very Strong':
        return Colors.blue;
      default:
        return Colors.red; // Default color if strength is not recognized
    }
  }

// Your existing function remains largely the same
  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '❤️ Empty';

    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final length = password.length;

    if (length < 6) return '💔 Weak';

    int strength = 0;
    if (hasUpperCase) strength++;
    if (hasLowerCase) strength++;
    if (hasDigits) strength++;
    if (hasSpecial) strength++;
    if (length >= 10) strength++;

    switch (strength) {
      case 1:
        return '🖤 Very Weak';
      case 2:
        return '❤️ Weak';
      case 3:
        return '💛 Medium';
      case 4:
        return '💚 Strong';
      case 5:
        return '💙 Very Strong';
      default:
        return '💔';
    }
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      // Set loading state before starting the registration process
      setState(() {
        _isLoading = true;
      });

      // Retrieve values from the controllers
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String contact = _contactController.text.trim();
      final String name =
          _nameController.text.trim(); // Ensure name is captured
      final String? referralCode = _referralCode; // Optional referral code

      try {
        // Get AuthProvider instance using Provider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Register the user with provided details
        await authProvider.register(
            email, password, name, contact, referralCode);

        // Check if the user is logged in after registration
        if (authProvider.isLoggedIn()) {
          // Registration successful, handle post-registration actions here
          // Navigate to the HomeScreen if the user is logged in
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Registration successful!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        // Handle errors that occur during registration
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));

        debugPrint("Error during registration: $e");
      } finally {
        // Ensure loading state is reset after the process is complete
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}