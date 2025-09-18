import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

class ColorLightenTest extends StatelessWidget {
  const ColorLightenTest({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = ThemeProvider.availableColors;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Lighten Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Color Lighten Verification',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This test verifies that the AppColors.lighten method works correctly for all available colors.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ...colors.map((color) {
              final lightenedColor = AppColors.lighten(color);
              final areDifferent = color != lightenedColor;
              
              return _ColorTestItem(
                originalColor: color,
                lightenedColor: lightenedColor,
                areDifferent: areDifferent,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _ColorTestItem extends StatelessWidget {
  final Color originalColor;
  final Color lightenedColor;
  final bool areDifferent;

  const _ColorTestItem({
    required this.originalColor,
    required this.lightenedColor,
    required this.areDifferent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ColorBox(
                  color: originalColor,
                  label: 'Original',
                ),
                const SizedBox(width: 16),
                _ColorBox(
                  color: lightenedColor,
                  label: 'Lightened',
                ),
                const SizedBox(width: 16),
                Icon(
                  areDifferent ? Icons.check_circle : Icons.error,
                  color: areDifferent ? Colors.green : Colors.red,
                  size: 30,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Original: ${originalColor.value.toRadixString(16).toUpperCase()}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text(
              'Lightened: ${lightenedColor.value.toRadixString(16).toUpperCase()}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text(
              areDifferent ? '✓ Colors are different' : '✗ Colors are identical',
              style: TextStyle(
                color: areDifferent ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorBox extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorBox({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}