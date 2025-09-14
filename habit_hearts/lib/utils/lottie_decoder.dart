import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

/// Custom decoder for .lottie files
Future<LottieComposition?> lottieFileDecoder(List<int> bytes) {
  return LottieComposition.decodeZip(
    bytes,
    filePicker: (files) {
      // Try to find the main animation file
      // This is a common pattern in .lottie files
      return files.firstWhereOrNull(
        (f) => f.name.startsWith('animations/') && f.name.endsWith('.json'),
      ) ??
          files.firstWhereOrNull(
            (f) => f.name.endsWith('.json'),
          ) ??
          files.first; // Fallback to first file if no JSON found
    },
  );
}