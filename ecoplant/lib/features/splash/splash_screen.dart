import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextScreen});
  final Widget nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _reveal;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _reveal = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _timer = Timer(const Duration(seconds: 3), _openHome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _openHome() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FAF4), Color(0xFFEDF3E5), Color(0xFFDCE8D5)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(top: -115, right: -130, child: _Halo(size: 350)),
          const Positioned(bottom: -180, left: -170, child: _Halo(size: 430)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NATURE MEETS INTELLIGENCE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2.6,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: FadeTransition(
                            opacity: _reveal,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(_reveal),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.9,
                                      end: 1,
                                    ).animate(_reveal),
                                    child: const ExcludeSemantics(
                                      child: Icon(
                                        Icons.eco_rounded,
                                        size: 140,
                                        color: AppColors.forest700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  const Text(
                                    'EcoPlant',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1.5,
                                      color: AppColors.forest900,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Kenali daun.\nRawat kehidupan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.5,
                                      color: AppColors.ink600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 92,
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  color: AppColors.forest700,
                                  backgroundColor: Color(0xFFD4E0CB),
                                  semanticsLabel: 'Menyiapkan aplikasi',
                                ),
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Menyiapkan aplikasi...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.ink600,
                              ),
                            ),
                            SizedBox(height: 28),
                            Text(
                              'DETEKSI PENYAKIT DAUN PISANG',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.7,
                                color: AppColors.ink600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x224F7B3A)),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x084F7B3A),
          border: Border.all(color: const Color(0x184F7B3A)),
        ),
      ),
    ),
  );
}
