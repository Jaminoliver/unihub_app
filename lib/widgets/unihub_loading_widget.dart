import 'package:flutter/material.dart';
import 'dart:math' show sin, pi;

class UniHubLoader extends StatefulWidget {
  final double size;
  final Color? backgroundColor;
  
  const UniHubLoader({
    super.key,
    this.size = 80.0,
    this.backgroundColor,
  });

  @override
  State<UniHubLoader> createState() => _UniHubLoaderState();
}

class _UniHubLoaderState extends State<UniHubLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Shimmer animation for skeleton effect
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Bounce animation for checkmark (up and down continuously)
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if the size is small (e.g., less than 30px, for use in buttons)
    final bool isSmallSize = widget.size < 30.0;
    
    // For small sizes, only show the main logo part to prevent overflow
    if (isSmallSize) {
        return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
                alignment: Alignment.center,
                children: [
                    // Shopping cart with shimmer effect - Bigger
                    AnimatedBuilder(
                        animation: _shimmerAnimation,
                        builder: (context, child) {
                            final shimmerValue = sin(_shimmerAnimation.value * pi * 2) * 0.5 + 0.5;
                            final opacity = 0.3 + (shimmerValue * 0.4); // Range: 0.3 to 0.7
                            
                            return Opacity(
                                opacity: opacity,
                                child: Icon(
                                    Icons.shopping_cart_rounded,
                                    size: widget.size * 0.9, // Make it a bit bigger for visibility
                                    color: const Color(0xFFD0D0D0), // Light gray
                                ),
                            );
                        },
                    ),
                    
                    // Bouncing checkmark
                    AnimatedBuilder(
                        animation: _bounceAnimation,
                        builder: (context, child) {
                            // Scale down the bounce effect for tiny buttons
                            final bounceValue = sin(_bounceAnimation.value * pi * 2);
                            final yOffset = bounceValue * widget.size * 0.1; // Reduced bounce height
                            
                            final shimmerValue = sin(_shimmerAnimation.value * pi * 2) * 0.5 + 0.5;
                            final opacity = 0.4 + (shimmerValue * 0.4);
                            
                            return Transform.translate(
                                offset: Offset(0, -yOffset),
                                child: Opacity(
                                    opacity: opacity,
                                    child: Icon(
                                        Icons.done_rounded,
                                        color: const Color(0xFFC0C0C0), // Medium gray
                                        size: widget.size * 0.5,
                                        weight: 900,
                                    ),
                                ),
                            );
                        },
                    ),
                ],
            ),
        );
    }

    // --- Original Code Path (for size >= 30.0) ---
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo - No container, no border
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shopping cart with shimmer effect - Bigger
              AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  final shimmerValue = sin(_shimmerAnimation.value * pi * 2) * 0.5 + 0.5;
                  final opacity = 0.3 + (shimmerValue * 0.4); // Range: 0.3 to 0.7
                  
                  return Opacity(
                    opacity: opacity,
                    child: Icon(
                      Icons.shopping_cart_rounded,
                      size: widget.size * 0.7,
                      color: const Color(0xFFD0D0D0), // Light gray
                    ),
                  );
                },
              ),
              
              // Bouncing checkmark - Bolder with rounded edges
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  // Bounce up and down: 0 = in cart, 1 = above cart
                  final bounceValue = sin(_bounceAnimation.value * pi * 2);
                  // Negative offset moves up, positive moves down
                  final yOffset = bounceValue * widget.size * 0.4;
                  
                  // Shimmer effect on checkmark
                  final shimmerValue = sin(_shimmerAnimation.value * pi * 2) * 0.5 + 0.5;
                  final opacity = 0.4 + (shimmerValue * 0.4); // Range: 0.4 to 0.8
                  
                  return Transform.translate(
                    offset: Offset(0, -yOffset),
                    child: Opacity(
                      opacity: opacity,
                      child: Icon(
                        Icons.done_rounded,
                        color: const Color(0xFFC0C0C0), // Medium gray
                        size: widget.size * 0.5,
                        weight: 900,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        SizedBox(height: widget.size * 0.25),
        
        // Animated Loading Dots with shimmer
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.15;
                final value = (_controller.value - delay).clamp(0.0, 1.0);
                final scale = (sin(value * pi * 2) * 0.5 + 0.5).clamp(0.3, 1.0);
                
                // Shimmer opacity for dots
                final shimmerValue = sin((value + _shimmerAnimation.value) * pi * 2) * 0.5 + 0.5;
                final opacity = 0.3 + (shimmerValue * 0.5); // Range: 0.3 to 0.8
                
                return Opacity(
                  opacity: opacity,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: widget.size * 0.04),
                    width: widget.size * 0.1,
                    height: widget.size * 0.1,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D0D0), // Light gray
                      borderRadius: BorderRadius.circular(widget.size * 0.05),
                      ),
                    transform: Matrix4.identity()..scale(scale),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}