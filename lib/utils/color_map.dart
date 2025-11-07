// lib/utils/color_map.dart

import 'dart:ui';

class ColorMap {
  // Fast color scheme: blue -> cyan -> green -> yellow -> red
  static Color getFastColor(double value, double minValue, double maxValue) {
    // Normalize value to 0-1
    double normalized;
    if (maxValue > minValue) {
      normalized = (value - minValue) / (maxValue - minValue);
    } else {
      normalized = 0.5; // Default to middle if all values are the same
    }
    normalized = normalized.clamp(0.0, 1.0);

    // Define color stops for "fast" gradient
    // 0.0 -> blue (0, 0, 255)
    // 0.25 -> cyan (0, 255, 255)
    // 0.5 -> green (0, 255, 0)
    // 0.75 -> yellow (255, 255, 0)
    // 1.0 -> red (255, 0, 0)

    int r, g, b;

    if (normalized < 0.25) {
      // Blue to Cyan: increase green
      double t = normalized / 0.25;
      r = 0;
      g = (255 * t).round();
      b = 255;
    } else if (normalized < 0.5) {
      // Cyan to Green: decrease blue
      double t = (normalized - 0.25) / 0.25;
      r = 0;
      g = 255;
      b = (255 * (1 - t)).round();
    } else if (normalized < 0.75) {
      // Green to Yellow: increase red
      double t = (normalized - 0.5) / 0.25;
      r = (255 * t).round();
      g = 255;
      b = 0;
    } else {
      // Yellow to Red: decrease green
      double t = (normalized - 0.75) / 0.25;
      r = 255;
      g = (255 * (1 - t)).round();
      b = 0;
    }

    return Color.fromARGB(255, r, g, b);
  }

  // Get a gradient for display in legend
  static List<Color> getFastGradient(int steps) {
    final colors = <Color>[];
    for (int i = 0; i < steps; i++) {
      final value = i / (steps - 1);
      colors.add(getFastColor(value, 0.0, 1.0));
    }
    return colors;
  }

  // Format value for display
  static String formatValue(double value) {
    if (value.abs() < 0.001) {
      return value.toStringAsExponential(2);
    } else if (value.abs() < 1000) {
      return value.toStringAsFixed(3);
    } else {
      return value.toStringAsExponential(2);
    }
  }
}
