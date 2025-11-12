import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'dart:math' show sin, pi;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    final session = supabase.auth.currentSession;
    
    if (session != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/account_type');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Animation - Matching the image style
            FadeTransition(
              opacity: _logoAnimation,
              child: ScaleTransition(
                scale: _logoAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A5B), Color(0xFFFF6B35)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Shopping cart
                      const Icon(
                        Icons.shopping_cart_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                      // Animated checkmark - Purple Nike-style swoosh (inside cart basket)
                      AnimatedBuilder(
                        animation: _checkAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _checkAnimation.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(
                                0, 
                                -10 + (10 * (1 - _checkAnimation.value)) // Animates from top down into cart basket
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Color(0xFF5B4FB5), // Purple
                                size: 38,
                                weight: 700,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // UniHub Text Animation - Navy blue
            FadeTransition(
              opacity: _textAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(_textAnimation),
                child: Text(
                  'UniHub',
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B35), // Orange to match logo
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Animated Loading Dots - Orange theme
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final delay = index * 0.15;
                    final value = (_controller.value - delay).clamp(0.0, 1.0);
                    final scale = (sin(value * pi * 2) * 0.5 + 0.5).clamp(0.3, 1.0);
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: index == 1 
                            ? const Color(0xFFFF6B35) // Orange
                            : const Color(0xFFFF8A5B), // Light orange
                        borderRadius: BorderRadius.circular(3),
                      ),
                      transform: Matrix4.identity()..scale(scale),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}