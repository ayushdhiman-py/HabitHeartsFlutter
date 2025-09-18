import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/theme/app_theme.dart';
import '../lib/providers/theme_provider.dart';

void main() {
  group('AppColors lighten method', () {
    test('Lighten method produces different colors', () {
      final List<Color> colors = ThemeProvider.availableColors;
      
      expect(colors, isNotEmpty);
      
      for (final color in colors) {
        final lightenedColor = AppColors.lighten(color);
        expect(lightenedColor, isNot(equals(color)), 
          reason: 'Lightened color should be different from original for color: ${color.value}');
      }
    });
    
    test('Lighten method produces visible colors', () {
      final List<Color> colors = ThemeProvider.availableColors;
      
      for (final color in colors) {
        final lightenedColor = AppColors.lighten(color);
        // Check that the lightened color is not fully transparent
        expect(lightenedColor.alpha, greaterThan(0));
      }
    });
    
    test('Lighten method with different amounts', () {
      final Color baseColor = AppColors.electricBlue;
      
      final lightenedDefault = AppColors.lighten(baseColor);
      final lightenedMore = AppColors.lighten(baseColor, 0.4);
      final lightenedLess = AppColors.lighten(baseColor, 0.1);
      
      // All should be different from original
      expect(lightenedDefault, isNot(equals(baseColor)));
      expect(lightenedMore, isNot(equals(baseColor)));
      expect(lightenedLess, isNot(equals(baseColor)));
      
      // All should be different from each other
      expect(lightenedDefault, isNot(equals(lightenedMore)));
      expect(lightenedDefault, isNot(equals(lightenedLess)));
      expect(lightenedMore, isNot(equals(lightenedLess)));
    });
  });
}