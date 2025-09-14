import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/lottie_decoder.dart';

class LottieErrorHandlingDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lottie Error Handling Demo'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Example 1: Working Lottie with proper error handling
            _buildLottieExample(
              title: 'Working Animation',
              assetPath: 'assets/animations/calendar.json',
            ),
            
            // Example 2: Missing asset with error handling
            _buildLottieExample(
              title: 'Missing Asset',
              assetPath: 'assets/animations/nonexistent.json',
            ),
            
            // Example 3: .lottie file with custom decoder
            _buildLottieExample(
              title: '.lottie File',
              assetPath: 'assets/animations/RW1j2z2aZy.lottie',
              decoder: lottieFileDecoder,
            ),
            
            // Example 4: Malformed JSON with error handling
            _buildLottieExample(
              title: 'Malformed JSON',
              assetPath: 'assets/animations/malformed.json',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLottieExample({
    required String title,
    required String assetPath,
    dynamic decoder,
  }) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: Lottie.asset(
                assetPath,
                decoder: decoder,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        SizedBox(height: 10),
                        Text('Failed to load animation'),
                        Text(
                          error.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
                frameBuilder: (context, child, composition) {
                  if (composition == null) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return child;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}