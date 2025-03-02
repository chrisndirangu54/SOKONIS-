import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/screens/login_screen.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import 'password_retrieval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.link});

  final String? link;

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _modelLoaded = false;
  bool _showAdditionalButtons = false; // Added for FAB toggle
  String _passwordStrength = '❤️ Empty';
  String? _referralCode;
  String _countryCode = '+254';
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
    _contactController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    print('Building RegisterScreen');
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
            const Text('Register'),
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
                        'Create an Account',
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
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your email' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: CountryCodePicker(
                              onChanged: (code) {
                                setState(() {
                                  _countryCode = code.dialCode ?? '+254';
                                });
                              },
                              initialSelection: 'Kenya',
                              favorite: const ['+254', 'Kenya'],
                              showCountryOnly: false,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _contactController,
                              decoration: const InputDecoration(labelText: 'Contact Number'),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                        ),
                        obscureText: !_passwordVisible,
                        validator: (value) => value!.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                        onChanged: (value) => setState(() {
                          _passwordStrength = _getPasswordStrength(value);
                        }),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: _passwordStrength.substring(0, 2),
                              style: TextStyle(
                                color: _getPasswordStrengthColor(_passwordStrength),
                              ),
                            ),
                            TextSpan(
                              text: _passwordStrength.substring(2),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegistration,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),),
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Main FAB (toggle button)
          FloatingActionButton(
            onPressed: () {
              setState(() {
                if (_showAdditionalButtons) {
                  _fabController.reverse();
                } else {
                  _fabController.forward();
                }
                _showAdditionalButtons = !_showAdditionalButtons;
              });
            },
            child: Icon(_showAdditionalButtons ? Icons.close : Icons.more_vert),
          ),
          // "Login" button
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              final offset = Offset(0, -80 * _fabController.value);
              return Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: _fabController.value,
                  child: FloatingActionButton.extended(
                    onPressed: _showAdditionalButtons
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            )
                        : null,
                    label: const Text('Login'),
                    icon: const Icon(Icons.login),
                  ),
                ),
              );
            },
          ),
          // "Forgot Password?" button
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              final offset = Offset(-60 * _fabController.value, -60 * _fabController.value);
              return Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: _fabController.value,
                  child: FloatingActionButton.extended(
                    onPressed: _showAdditionalButtons
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PasswordRetrievalScreen()),
                            )
                        : null,
                    label: const Text('Forgot Password?'),
                    icon: const Icon(Icons.lock_reset),
                  ),
                ),
              );
            },
          ),
          // "Login with Google" button
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              final offset = Offset(-80 * _fabController.value, 0);
              return Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: _fabController.value,
                  child: FloatingActionButton.extended(
                    onPressed: _showAdditionalButtons ? _signInWithGoogle : null,
                    label: const Text('Login with Google'),
                    icon: const Icon(Icons.g_mobiledata_rounded),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


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
        return Colors.red;
    }
  }

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
        return '💔 Weak';
    }
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String contact = _countryCode + _contactController.text.trim();
      final String name = _nameController.text.trim();
      final String? referralCode = _referralCode;

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.register(email, password, name, contact, referralCode);
        if (authProvider.isLoggedIn && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration failed')),
          );
        }
      } catch (e) {
        if (mounted) {
          print('Registration error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e')),
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
        Navigator.of(context).pushReplacement(
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