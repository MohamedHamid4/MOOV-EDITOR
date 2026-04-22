import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _ringsCtrl;

  // Logo
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // "Moov"
  late final Animation<double> _moovFade;
  late final Animation<Offset> _moovSlide;

  // "Editor"
  late final Animation<double> _editorFade;
  late final Animation<Offset> _editorSlide;

  // Tagline
  late final Animation<double> _taglineFade;

  // Progress bar
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _ringsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.00, 0.14, curve: Curves.easeOut),
    );
    _logoScale = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.00, 0.28, curve: Curves.elasticOut),
    );

    _moovFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.14, 0.30, curve: Curves.easeOut),
    );
    _moovSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.14, 0.30, curve: Curves.easeOut),
    ));

    _editorFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.22, 0.37, curve: Curves.easeOut),
    );
    _editorSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.22, 0.37, curve: Curves.easeOut),
    ));

    _taglineFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.33, 0.50, curve: Curves.easeOut),
    );

    _progress = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.07, 0.93, curve: Curves.linear),
    );

    _mainCtrl.forward();
    _mainCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigate();
    });
  }

  void _navigate() {
    if (!mounted) return;
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    Navigator.of(context).pushReplacementNamed(isSignedIn ? '/home' : '/login');
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _ringsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Expanding rings background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ringsCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RingsPainter(
                  progress: _ringsCtrl.value,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // Radial gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.2),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: AnimatedBuilder(
              animation: _mainCtrl,
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Hero(
                        tag: 'app_logo',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // "Moov"
                  FadeTransition(
                    opacity: _moovFade,
                    child: SlideTransition(
                      position: _moovSlide,
                      child: const Text(
                        'Moov',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),

                  // "Editor"
                  FadeTransition(
                    opacity: _editorFade,
                    child: SlideTransition(
                      position: _editorSlide,
                      child: const Text(
                        'Editor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      'Edit. Create. Moov.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Progress bar
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        backgroundColor: AppColors.darkBorder,
                        color: AppColors.primary,
                        minHeight: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.7;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final radius = p * maxRadius;
      final opacity = (1.0 - p) * 0.18;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.progress != progress;
}
