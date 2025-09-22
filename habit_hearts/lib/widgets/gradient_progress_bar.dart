import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientProgressBar extends StatelessWidget {
  final double completedPercentage; // 0.0 to 1.0
  final double missedPercentage;    // 0.0 to 1.0
  final double height;
  final Color completedColor;
  final Color missedColor;
  final Color backgroundColor;

  const GradientProgressBar({
    super.key,
    required this.completedPercentage,
    required this.missedPercentage,
    this.height = 10.0,
    this.completedColor = AppColors.vibrantGreen,
    this.missedColor = AppColors.coralRed,
    this.backgroundColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _ProgressBarPainter(
        completedPercentage: completedPercentage,
        missedPercentage: missedPercentage,
        completedColor: completedColor,
        missedColor: missedColor,
        backgroundColor: backgroundColor,
        borderRadius: height / 2,
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double completedPercentage;
  final double missedPercentage;
  final Color completedColor;
  final Color missedColor;
  final Color backgroundColor;
  final double borderRadius;

  _ProgressBarPainter({
    required this.completedPercentage,
    required this.missedPercentage,
    required this.completedColor,
    required this.missedColor,
    required this.backgroundColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = backgroundColor;
    final completedPaint = Paint()..color = completedColor;
    final missedPaint = Paint()..color = missedColor;

    // Draw background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ),
      backgroundPaint,
    );

    // Draw completed progress
    final completedWidth = size.width * completedPercentage;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, completedWidth, size.height),
        Radius.circular(borderRadius),
      ),
      completedPaint,
    );

    // Draw missed progress
    final missedWidth = size.width * missedPercentage;
    final missedStart = completedWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(missedStart, 0, missedWidth, size.height),
        Radius.circular(borderRadius),
      ),
      missedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return completedPercentage != oldDelegate.completedPercentage ||
           missedPercentage != oldDelegate.missedPercentage ||
           completedColor != oldDelegate.completedColor ||
           missedColor != oldDelegate.missedColor ||
           backgroundColor != oldDelegate.backgroundColor;
  }
}