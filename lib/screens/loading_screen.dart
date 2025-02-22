import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart'; // Correct package for gyroscope events
import 'package:grocerry/screens/home_screen.dart'; // Replace with your actual HomeScreen import

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  LoadingScreenState createState() => LoadingScreenState();
}

class LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  bool loadingComplete = false;
  double _rotationY = 0.0;
  double _rotationX = 0.0;
  final double _scale = 1.0;
  late AnimationController _controller;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _simulateLoading();

    // Initialize gyroscope stream
    gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _rotationY += event.y * 0.01;
        _rotationX += event.x * 0.01;
      });
    });
  }

  void _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 7));
    _onLoadingComplete();
  }

  void _onLoadingComplete() {
    setState(() {
      loadingComplete = true;
    });

    // Delay navigation by 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!loadingComplete)
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateX(_rotationX + _controller.value * 0.1)
                      ..rotateY(_rotationY + _controller.value * 0.1)
                      ..scale(_scale),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(
                            MediaQuery.of(context).size.width * 0.5,
                            MediaQuery.of(context).size.height * 0.5,
                          ),
                          painter: WaterRipplePainter(_controller),
                        ),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: BorderGradientPainter(_pulseController),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30.0),
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.5,
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                        child: Container(),
                                      ),
                                      const Image(
                                        image: AssetImage("assets/images/basket.png"),
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (loadingComplete)
            const Center(
              child: BounceText(
                text: "SOKONI'S!",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class WaterRipplePainter extends CustomPainter {
  final Animation<double> animation;

  WaterRipplePainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blue.withOpacity(0.5 - animation.value * 0.5);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.5 * animation.value;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(WaterRipplePainter oldDelegate) => true;
}

class BorderGradientPainter extends CustomPainter {
  final Animation<double> animation;
  final double pulseWidth;

  BorderGradientPainter(this.animation, {this.pulseWidth = 4.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pulseWidth + pulseWidth * animation.value * 0.5 // Pulsating effect
      ..shader = LinearGradient(
        colors: [Colors.blue, Colors.purple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final rect = Rect.fromLTRB(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(30.0)),
      paint,
    );
  }

  @override
  bool shouldRepaint(BorderGradientPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}

class BounceText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const BounceText({
    required this.text,
    required this.style,
    super.key,
  });

  @override
  State<BounceText> createState() => _BounceTextState();
}

class _BounceTextState extends State<BounceText> with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < widget.text.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final animation = Tween<double>(begin: 0, end: -10.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.bounceOut,
        ),
      );
      _controllers.add(controller);
      _animations.add(animation);

      Future.delayed(Duration(milliseconds: 100 * i), () {
        controller.forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.text.length, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Text(
                widget.text[index],
                style: widget.style,
              ),
            );
          },
        );
      }),
    );
  }
}