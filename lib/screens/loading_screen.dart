import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grocerry/screens/home_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _simulateLoading();

    // Initialize gyroscope stream
    gyroscopeEventStream().listen((GyroscopeEvent event) {
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

    // Delay navigation by 5 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const HomeScreen()), // Replace 'HomeScreen' with your actual home screen widget
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30.0),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30.0),
                                border: Border.all(
                                  color: Colors.orange
                                      .withOpacity(0.6 * _controller.value),
                                  width: 4.0,
                                ),
                              ),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.5,
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: const Image(
                                  image: AssetImage("assets/images/basket.png"),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
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
                  color: Colors.deepOrangeAccent,
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
    super.dispose();
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

class _BounceTextState extends State<BounceText>
    with SingleTickerProviderStateMixin {
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

// Custom Painter for Water Ripple Effect
class WaterRipplePainter extends CustomPainter {
  final Animation<double> _animation;

  WaterRipplePainter(this._animation) : super(repaint: _animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    double rippleRadius =
        size.width * 0.4 + (_animation.value * size.width * 0.3);

    canvas.drawCircle(size.center(Offset.zero), rippleRadius, paint);

    final secondaryPaint = Paint()..color = Colors.blueAccent.withOpacity(0.2);

    canvas.drawCircle(
        size.center(Offset.zero), rippleRadius / 2, secondaryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
