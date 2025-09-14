import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:collection/collection.dart';

class LottieUtils {
  /// Custom decoder for .lottie files
  static Future<LottieComposition?> decodeLottieFile(String assetName) async {
    try {
      // Load the asset as bytes
      ByteData data = await rootBundle.load(assetName);
      Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      
      // Decode the .lottie file (which is essentially a ZIP archive)
      return LottieComposition.decodeZip(
        bytes,
        filePicker: (files) {
          // Try to find the main animation file
          // Most .lottie files contain a single JSON file in an 'animations' folder
          return files.firstWhereOrNull(
                (f) => f.name.startsWith('animations/') && f.name.endsWith('.json'),
              ) ??
              files.firstWhereOrNull(
                (f) => f.name.endsWith('.json'),
              ) ??
              files.first; // Fallback to first file if no JSON found
        },
      );
    } catch (e) {
      // Return null if decoding fails
      return null;
    }
  }
}