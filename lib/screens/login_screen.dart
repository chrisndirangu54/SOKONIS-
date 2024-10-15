import 'dart:async';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart'; // Import ModelViewer

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';
// for TickerProvider

import '../providers/auth_provider.dart';
// Import UserProvider
import '../screens/home_screen.dart';
import 'password_retrieval_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false; // To toggle password visibility
  bool _showAdditionalButtons = false; // To toggle buttons visibility
  bool _isLoading = false; // To manage the loading indicator
  String? _referralCode; // Store the referral code

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
            const SizedBox(width: 8), // Space between logo and title
            const Text('Login'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4, // Add elevation to make it appear elevated
            color: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12.0), // Optional: add rounded corners
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
                              !_isLoading, // Disable camera controls when loading
                          disablePan:
                              _isLoading, // Disable panning when loading
                          disableZoom:
                              _isLoading, // Disable zooming when loading
                          autoRotateDelay:
                              0, // Start rotating immediately when loading
                          cameraOrbit: _isLoading
                              ? "0deg 90deg 2.5m"
                              : "0deg 0deg 2.5m", // Define camera angle
                        )),

                    const SizedBox(height: 20),

                    // Welcome Text
                    Text(
                      'Welcome Back',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Email TextFormField
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password TextFormField with visibility toggle
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: _showPassword
                                ? Colors.orange
                                : Colors.black, // Change color here,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: _isLoading
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
                        }),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final tiltValue = 0.03 *
                                _controller.value; // Slight tilt for 3D effect
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
                              child: _isLoading
                                  ? Center(
                                      child: Stack(
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
                                              width: 80,
                                              height: 80,
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
                                            strokeWidth: 4.0,
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                setState(() {
                                                  _isLoading =
                                                      true; // Start loading animation
                                                });
                                                try {
                                                  await Provider.of<
                                                              AuthProvider>(
                                                          context,
                                                          listen: false)
                                                      .login(
                                                          _emailController.text,
                                                          _passwordController
                                                              .text);

                                                  bool isLoggedIn =
                                                      Provider.of<AuthProvider>(
                                                                  context,
                                                                  listen: false)
                                                              .isLoggedIn ==
                                                          true;

                                                  if (isLoggedIn &&
                                                      context.mounted) {
                                                    Navigator.of(context)
                                                        .pushReplacement(
                                                            MaterialPageRoute(
                                                                builder: (_) =>
                                                                    const HomeScreen()));
                                                  } else if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Login failed: Invalid credentials')));
                                                  }
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Login failed')));
                                                  }
                                                } finally {
                                                  setState(() {
                                                    _isLoading =
                                                        false; // Stop loading animation
                                                  });
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 50, vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50.0),
                                        ),
                                        elevation: 7,
                                        shadowColor: Colors.grey[700],
                                        side: const BorderSide(
                                            color: Colors.blue, width: 1),
                                      ),
                                      child: const Text(
                                        'Login',
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
                  ],
                ),
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
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final scale =
                    1 - (_controller.value * 0.1); // Scale down by 10%

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Set perspective
                    ..scale(scale), // Apply scaling
                  alignment: Alignment.center,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _showAdditionalButtons = !_showAdditionalButtons;
                      });
                    },
                    child: Icon(
                        _showAdditionalButtons ? Icons.close : Icons.more_vert),
                  ),
                );
              },
            ),
            if (_showAdditionalButtons) ...[
              Transform.translate(
                offset: const Offset(0, -80), // Vertical positioning
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/register');
                  },
                  label: const Text('Register'),
                  icon: const Icon(Icons.person_add),
                ),
              ),
              Transform.translate(
                offset: const Offset(-60, -60), // Diagonal positioning
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PasswordRetrievalScreen()));
                  },
                  label: const Text('Forgot Password?'),
                  icon: const Icon(Icons.lock_reset),
                ),
              ),
              Transform.translate(
                offset: const Offset(-80, 0), // Horizontal positioning
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    setState(() {
                      _isLoading = true; // Start loading for Google sign-in
                    });
                    try {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .signInWithGoogle(_referralCode);

                      if (Provider.of<AuthProvider>(context, listen: false)
                          .isLoggedIn()) {
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()));
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Google sign-in failed')));
                        }
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Google sign-in failed')));
                      }
                    } finally {
                      setState(() {
                        _isLoading = false; // Stop loading after Google sign-in
                      });
                    }
                  },
                  label: const Text('Login with Google'),
                  icon: const Icon(Icons.g_mobiledata_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
