import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/lottie_decoder.dart';

class LottieHeaderAnimation extends StatelessWidget {
  const LottieHeaderAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    // First, try the .lottie file, and if it fails, fall back to a .json file
    return Lottie.asset(
      'assets/animations/RW1j2z2aZy.lottie',
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      decoder: lottieFileDecoder, // Custom decoder for .lottie files
      errorBuilder: (context, error, stackTrace) {
        // Try a fallback .json animation
        return Lottie.asset(
          'assets/animations/calendar.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // If both fail, show fallback UI
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.animation_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Animation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      frameBuilder: (context, child, composition) {
        // Show a loading indicator while the animation is loading
        if (composition == null) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}