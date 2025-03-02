import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import 'password_retrieval_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _showAdditionalButtons = false;
  bool _isLoading = false;
  bool _modelLoaded = false;
  String? _referralCode;
  final AppLinks _appLinks = AppLinks();

  late AnimationController _logoController;
  late AnimationController _buttonController;
  late AnimationController _fabController;
  late AnimationController _controller;
  late AnimationController _loadingController;
  late StreamSubscription _linkSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && mounted) _parseReferralCode(uri.toString());
    });

      _linkSubscription = _appLinks.stringLinkStream.listen((String? link) {

        if (link != null && mounted) _parseReferralCode(link);
      },
      onError: (err) {
        if (mounted) {
          print("Error listening for links: $err");
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
      await Future.delayed(const Duration(milliseconds: 100)); // Simulate load
      if (mounted) setState(() => _modelLoaded = true);
    } catch (e) {
      if (mounted) setState(() => _modelLoaded = false);
    }
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    _controller.dispose();
    _fabController.dispose();
    _logoController.dispose();
    _buttonController.dispose();
    _loadingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) => _controller.reverse(),
              onTapCancel: () => _controller.reverse(), // Fixed: No parameter
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: GlassmorphicContainer(
                  width: screenWidth * 0.25.clamp(80.0, 120.0),
                  height: screenWidth * 0.25.clamp(80.0, 120.0),
                  borderRadius: 20,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      final tiltValue = 0.02 *
                          Curves.elasticInOut.transform(_logoController.value);
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(tiltValue)
                          ..rotateX(tiltValue),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/basket.png',
                      height: screenWidth * 0.2.clamp(60.0, 100.0),
                      width: screenWidth * 0.2.clamp(60.0, 100.0),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Flexible(
              child: Text(
                'Login',
                style:
                    TextStyle(fontSize: screenWidth * 0.05.clamp(16.0, 24.0)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screenWidth * 0.06),
            child: Card(
              elevation: 4,
              color: Colors.grey[300],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: screenWidth * 0.7.clamp(200.0, 300.0),
                        width: screenWidth * 0.7.clamp(200.0, 300.0),
                        child: _modelLoaded
                            ? ModelViewer(
                                src: 'assets/3d/apple.glb',
                                alt: "A 3D model of an apple",
                                autoRotate: _isLoading,
                                cameraControls: !_isLoading,
                                disablePan: _isLoading,
                                disableZoom: _isLoading,
                                autoRotateDelay: 0,
                                cameraOrbit: _isLoading
                                    ? "0deg 90deg 2.5m"
                                    : "0deg 0deg 2.5m",
                              )
                            : const Center(
                                child: Text(
                                  'Failed to load 3D model',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Text(
                        'Welcome Back',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.06.clamp(20.0, 28.0),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.03),
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
                        style: TextStyle(
                            fontSize: screenWidth * 0.04.clamp(14.0, 18.0)),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color:
                                  _showPassword ? Colors.orange : Colors.black,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        obscureText: !_showPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        style: TextStyle(
                            fontSize: screenWidth * 0.04.clamp(14.0, 18.0)),
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _isLoading
                                  ? Colors.orange.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.2),
                              spreadRadius: 5,
                              blurRadius: 15,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTapDown: (_) => _buttonController.forward(),
                          onTapUp: (_) => _buttonController.reverse(),
                          child: AnimatedBuilder(
                            animation: _buttonController,
                            builder: (context, child) {
                              final tiltValue = 0.03 * _buttonController.value;
                              final scaleValue =
                                  1 - _buttonController.value * 0.1;
                              return Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.002)
                                  ..rotateX(tiltValue)
                                  ..rotateY(tiltValue)
                                  ..scale(scaleValue),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? Center(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ScaleTransition(
                                              scale: Tween<double>(
                                                      begin: 0.7, end: 1.0)
                                                  .animate(
                                                CurvedAnimation(
                                                  parent: _loadingController,
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                              child: Container(
                                                width: screenWidth *
                                                    0.2.clamp(60.0, 80.0),
                                                height: screenWidth *
                                                    0.2.clamp(60.0, 80.0),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.orange
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                            ),
                                            CircularProgressIndicator(
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(Colors.orange),
                                              strokeWidth:
                                                  isLargeScreen ? 6.0 : 4.0,
                                            ),
                                          ],
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                          backgroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.1,
                                            vertical: screenHeight * 0.02,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50.0),
                                          ),
                                          elevation: 7,
                                          shadowColor: Colors.grey[700],
                                          side: const BorderSide(
                                              color: Colors.blue, width: 1),
                                        ),
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: screenWidth *
                                                0.045.clamp(16.0, 20.0),
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
      ),
      floatingActionButton: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(), // Fixed: No parameter
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            AnimatedBuilder(
              animation: _fabController,
              builder: (context, child) {
                final scale = 1 - (_fabController.value * 0.1);
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scale(scale),
                  alignment: Alignment.center,
                  child: FloatingActionButton(
                    onPressed: () => setState(
                        () => _showAdditionalButtons = !_showAdditionalButtons),
                    child: Icon(
                        _showAdditionalButtons ? Icons.close : Icons.more_vert),
                  ),
                );
              },
            ),
            if (_showAdditionalButtons) ...[
              Transform.translate(
                offset: Offset(0, -(screenHeight * 0.1).clamp(60.0, 80.0)),
                child: FloatingActionButton.extended(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/register'),
                  label: Text('Register',
                      style: TextStyle(
                          fontSize: screenWidth * 0.04.clamp(14.0, 16.0))),
                  icon: const Icon(Icons.person_add),
                ),
              ),
              Transform.translate(
                offset: Offset(-(screenWidth * 0.15).clamp(50.0, 60.0),
                    -(screenHeight * 0.08).clamp(50.0, 60.0)),
                child: FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PasswordRetrievalScreen())),
                  label: Text('Forgot Password?',
                      style: TextStyle(
                          fontSize: screenWidth * 0.04.clamp(14.0, 16.0))),
                  icon: const Icon(Icons.lock_reset),
                ),
              ),
              Transform.translate(
                offset: Offset(-(screenWidth * 0.2).clamp(70.0, 80.0), 0),
                child: FloatingActionButton.extended(
                  onPressed: _signInWithGoogle,
                  label: Text('Login with Google',
                      style: TextStyle(
                          fontSize: screenWidth * 0.04.clamp(14.0, 16.0))),
                  icon: const Icon(Icons.g_mobiledata_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.login(
            _emailController.text, _passwordController.text);
        if (authProvider.isLoggedIn && mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Login failed: Invalid credentials')));
        }
      } catch (error) {
        if (mounted) {
          print('Login error: $error');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Login failed: $error')));
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
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in failed')));
      }
    } catch (error) {
      if (mounted) {
        print('Google sign-in error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

extension NumExtension on num {
  num clamp(num min, num max) => this < min ? min : (this > max ? max : this);
}
