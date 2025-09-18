import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final List<Color> gradientColors;

  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.gradientColors = AppColors.purpleToPinkGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height), // Fully rounded
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2, // Reduced blur radius for better performance
            offset: const Offset(0, 1), // Reduced offset for better performance
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(
            gradientColors.first,
          ),
          minHeight: height,
        ),
      ),
    );
  }
}