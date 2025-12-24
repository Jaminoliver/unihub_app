import 'package:flutter/material.dart';
import 'dart:math' show sin, pi;

class UniHubLoader extends StatefulWidget {
  final double size;
  final Color? color;
  
  const UniHubLoader({
    super.key,
    this.size = 80.0,
    this.color,
  });

  @override
  State<UniHubLoader> createState() => _UniHubLoaderState();
}

class _UniHubLoaderState extends State<UniHubLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaderColor = widget.color ?? const Color(0xFFFF6B35);
    final bool isSmallSize = widget.size < 40.0;
    
    if (isSmallSize) {
      // Mini version for buttons
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 3.0,
          valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
        ),
      );
    }

    // Professional loader - Logo with spinning gradient ring
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning gradient ring
                  Transform.rotate(
                    angle: _controller.value * 2 * pi,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            loaderColor.withOpacity(0.1),
                            loaderColor,
                            loaderColor.withOpacity(0.1),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  
                  // Inner white circle (ring effect)
                  Container(
                    width: widget.size * 0.85,
                    height: widget.size * 0.85,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Logo with pulse
                  Transform.scale(
                    scale: 0.95 + (sin(_controller.value * pi * 2) * 0.05),
                    child: Container(
                      width: widget.size * 0.6,
                      height: widget.size * 0.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: loaderColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/unihub_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        SizedBox(height: widget.size * 0.25),
        
        // Animated dots
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final value = (_controller.value - delay).clamp(0.0, 1.0);
                final scale = (sin(value * pi * 2) * 0.5 + 0.5).clamp(0.4, 1.0);
                
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: widget.size * 0.04),
                  width: widget.size * 0.08,
                  height: widget.size * 0.08,
                  decoration: BoxDecoration(
                    color: loaderColor,
                    shape: BoxShape.circle,
                  ),
                  transform: Matrix4.identity()..scale(scale),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}