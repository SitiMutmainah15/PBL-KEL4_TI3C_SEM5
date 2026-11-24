import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  final Widget nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Color palette
  static const Color _background = Color(0xFFF7F8F3);
  static const Color _primary = Color(0xFF164D2C);
  static const Color _secondary = Color(0xFF4C8826);
  static const Color _muted = Color(0xFF637367);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _timer = Timer(
      const Duration(seconds: 3),
      _openHome,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  // Navigasi ke halaman selanjutnya
  void _openHome() {
    if (!mounted) return;

    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration(
          milliseconds: reduceMotion ? 0 : 400,
        ),
        pageBuilder: (context, animation, secondaryAnimation) {
          return widget.nextScreen;
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: [
                // Area utama: logo, nama, tagline
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/icons/LOGO.png',
                              width: 68,
                              height: 68,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'EcoPlant',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: _primary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Kenali daun, rawat kehidupan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Penanda loading: satu titik kecil
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Semantics(
                    label: 'Menyiapkan aplikasi',
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
