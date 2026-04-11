import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInit;
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onInit, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _illustrationCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  double _progress = 0.0;
  String _statusText = 'Starting up...';

  @override
  void initState() {
    super.initState();

    _illustrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = CurvedAnimation(parent: _illustrationCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _illustrationCtrl, curve: Curves.easeOutCubic),
    );

    _illustrationCtrl.forward();
    _runInit();
  }

  Future<void> _runInit() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _setProgress(0.3, 'Loading your goals...');
    await widget.onInit();
    await _setProgress(0.7, 'Loading your todos...');
    await Future.delayed(const Duration(milliseconds: 200));
    await _setProgress(1.0, 'All set!');
    await Future.delayed(const Duration(milliseconds: 400));
    widget.onDone();
  }

  Future<void> _setProgress(double value, String text) async {
    setState(() {
      _progress = value;
      _statusText = text;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _illustrationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _illustrationCtrl,
          builder: (context, _) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      // Animated illustration with gentle float
                      _FloatingIllustration(),
                      const SizedBox(height: 32),
                      Text('acuis',
                          style: GoogleFonts.comfortaa(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('your goals, your way',
                          style: GoogleFonts.comfortaa(
                              fontSize: 13,
                              color: AppColors.inkLight)),
                      const Spacer(flex: 2),
                      // Progress bar
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _progress),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              builder: (_, value, _) => LinearProgressIndicator(
                                value: value,
                                minHeight: 3,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(AppColors.ink),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_statusText,
                              style: GoogleFonts.comfortaa(
                                  fontSize: 11,
                                  color: AppColors.inkFaint)),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Gently floating illustration
class _FloatingIllustration extends StatefulWidget {
  @override
  State<_FloatingIllustration> createState() => _FloatingIllustrationState();
}

class _FloatingIllustrationState extends State<_FloatingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _float = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _float.value),
        child: Image.asset(
          'assets/splash_screen.png',
          width: 220,
        ),
      ),
    );
  }
}
