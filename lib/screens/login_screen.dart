import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import 'password_retrieval_screen.dart';
import 'register_screen.dart'; // Add this import for navigation

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _showAdditionalButtons = false;
  bool _isLoading = false;
  bool _modelLoaded = false;
  String? _referralCode;
  final AppLinks _appLinks = AppLinks();
  late AnimationController _fabController;
  late StreamSubscription _linkSubscription;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && mounted) _parseReferralCode(uri.toString());
    });

    _linkSubscription = _appLinks.stringLinkStream.listen(
      (String? link) {
        if (link != null && mounted) _parseReferralCode(link);
      },
      onError: (err) {
        if (mounted) {
          print('Link error: $err');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link error: $err')),
          );
        }
      },
      cancelOnError: false,
    );

    _checkModelAvailability();
  }

  void _parseReferralCode(String link) {
    try {
      Uri uri = Uri.parse(link);
      if (mounted) {
        setState(() {
          _referralCode = uri.queryParameters['ref'];
          if (_referralCode != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Referral code applied: $_referralCode')),
            );
          }
        });
      }
    } catch (e) {
      print('Error parsing referral link: $e');
    }
  }

  Future<void> _checkModelAvailability() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) setState(() => _modelLoaded = true);
    } catch (e) {
      print('Model availability check failed: $e');
      if (mounted) setState(() => _modelLoaded = false);
    }
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    _fabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    print('Building LoginScreen, _modelLoaded: $_modelLoaded');
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/basket.png',
              height: 60,
              width: 60,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
            ),
            const SizedBox(width: 10),
            const Text('Login'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: screenWidth * 0.67, // 2/3 of screen width
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
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
                          height: screenWidth * 0.7, // Removed clamp
                          width: screenWidth * 0.7,  // Removed clamp
                          child: _modelLoaded
                              ? ModelViewer(
                                  src: 'assets/3d/apple.glb',
                                  alt: "A 3D model of an apple",
                                  autoRotate: true, // Always rotate for visibility
                                  cameraControls: true,
                                  disablePan: false,
                                  disableZoom: false,
                                  autoRotateDelay: 0,
                                  cameraOrbit: "0deg 75deg 105%", // Adjusted for better view
                                  exposure: 1.0, // Default brightness
                                  shadowIntensity: 1.0, // Add shadows
                                  backgroundColor: Colors.grey[200]!, // Light background

                                )
                              : const Center(
                                  child: Text(
                                    'Failed to load 3D model',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        AutoSizeText(
                          'Welcome Back',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          minFontSize: 20.0,
                          maxFontSize: 28.0,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
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
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
floatingActionButton: Stack(
  alignment: Alignment.bottomRight,
  children: [
    // Register Button
    AnimatedBuilder(
      animation: _fabController,
      builder: (context, child) {
        final offset = Offset(0, -120 * _fabController.value);
        return Transform.translate(
          offset: offset,
          child: Container(
            child: Opacity(
              opacity: _showAdditionalButtons ? _fabController.value : 0.0,
              child: FloatingActionButton.extended(
                onPressed: (_showAdditionalButtons && !_isLoading)
                    ? () async {
                        try {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                          if (mounted) {
                            _fabController.reverse();
                            setState(() => _showAdditionalButtons = false);
                          }
                        } catch (e) {
                          print('Register navigation error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Navigation failed: $e')),
                            );
                          }
                        }
                      }
                    : null,
                label: const Text('Register'),
                icon: const Icon(Icons.person_add),
                backgroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                foregroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                elevation: _showAdditionalButtons ? 6.0 : 0.0,
              ),
            ),
          ),
        );
      },
    ),
    // Forgot Password Button
    AnimatedBuilder(
      animation: _fabController,
      builder: (context, child) {
        final offset = Offset(-60 * _fabController.value, -60 * _fabController.value);
        return Transform.translate(
          offset: offset,
          child: Container(
            child: Opacity(
              opacity: _showAdditionalButtons ? _fabController.value : 0.0,
              child: FloatingActionButton.extended(
                onPressed: (_showAdditionalButtons && !_isLoading)
                    ? () async {
                        try {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PasswordRetrievalScreen()),
                          );
                          if (mounted) {
                            _fabController.reverse();
                            setState(() => _showAdditionalButtons = false);
                          }
                        } catch (e) {
                          print('Password reset navigation error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Navigation failed: $e')),
                            );
                          }
                        }
                      }
                    : null,
                label: const Text('Forgot Password?'),
                icon: const Icon(Icons.lock_reset),
                backgroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                foregroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                elevation: _showAdditionalButtons ? 6.0 : 0.0,
              ),
            ),
          ),
        );
      },
    ),
    // Google Sign-in Button
    AnimatedBuilder(
      animation: _fabController,
      builder: (context, child) {
        final offset = Offset(-80 * _fabController.value, 0);
        return Transform.translate(
          offset: offset,
          child: Container(
            child: Opacity(
              opacity: _showAdditionalButtons ? _fabController.value : 0.0,
              child: FloatingActionButton.extended(
                onPressed: (_showAdditionalButtons && !_isLoading)
                    ? () async {
                        try {
                          await _signInWithGoogle();
                          if (mounted) {
                            _fabController.reverse();
                            setState(() => _showAdditionalButtons = false);
                          }
                        } catch (e) {
                          print('Google sign-in error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google sign-in failed: $e')),
                            );
                          }
                        }
                      }
                    : null,
                label: const Text('Login with Google'),
                icon: const Icon(Icons.g_mobiledata_rounded),
                backgroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                foregroundColor: _showAdditionalButtons 
                    ? null 
                    : Colors.transparent,
                elevation: _showAdditionalButtons ? 6.0 : 0.0,
              ),
            ),
          ),
        );
      },
    ),
    // Main FAB Toggle
    Container(
      child: FloatingActionButton(
        onPressed: () {
          if (mounted) {
            setState(() {
              if (_showAdditionalButtons) {
                _fabController.reverse();
              } else {
                _fabController.forward();
              }
              _showAdditionalButtons = !_showAdditionalButtons;
            });
          }
        },
        child: Icon(_showAdditionalButtons ? Icons.close : Icons.more_vert),
      ),
    ),
  ],
),
    );
  }
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.login(_emailController.text, _passwordController.text);
        if (authProvider.isLoggedIn && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed: Invalid credentials')),
          );
        }
      } catch (error) {
        if (mounted) {
          print('Login error: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle(_referralCode);
      if (authProvider.isLoggedIn && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed')),
        );
      }
    } catch (error) {
      if (mounted) {
        print('Google sign-in error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

extension NumExtension on num {
  num clamp(num min, num max) => this < min ? min : (this > max ? max : this);
}