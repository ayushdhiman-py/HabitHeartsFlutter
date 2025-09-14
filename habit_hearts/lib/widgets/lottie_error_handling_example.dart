import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/lottie_decoder.dart';

class AdvancedLottieErrorHandling extends StatefulWidget {
  @override
  _AdvancedLottieErrorHandlingState createState() =>
      _AdvancedLottieErrorHandlingState();
}

class _AdvancedLottieErrorHandlingState
    extends State<AdvancedLottieErrorHandling> {
  late Future<LottieComposition> _compositionFuture;

  @override
  void initState() {
    super.initState();
    // Preload the composition with error handling
    _compositionFuture = _loadLottieComposition();
  }

  Future<LottieComposition> _loadLottieComposition() async {
    try {
      // Attempt to load the Lottie composition
      final composition = await AssetLottie('assets/animations/RW1j2z2aZy.lottie').load();
      return composition;
    } catch (e) {
      // Re-throw the error to be caught by FutureBuilder
      throw Exception('Failed to load animation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Lottie Error Handling'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFutureBuilderExample(),
            _buildFallbackExample(),
          ],
        ),
      ),
    );
  }

  Widget _buildFutureBuilderExample() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. FutureBuilder Error Handling',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: FutureBuilder<LottieComposition>(
                future: _compositionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Show loading indicator while loading
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // Handle any errors that occurred during loading
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 50),
                          SizedBox(height: 10),
                          Text('Error loading animation'),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              // Retry loading
                              setState(() {
                                _compositionFuture = _loadLottieComposition();
                              });
                            },
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasData) {
                    // Display the loaded animation
                    return Lottie(composition: snapshot.data!);
                  } else {
                    // Fallback in case of unexpected state
                    return Center(child: Text('No animation available'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackExample() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Fallback Image Approach',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: Lottie.asset(
                'assets/animations/RW1j2z2aZy.lottie',
                decoder: lottieFileDecoder, // Custom decoder for .lottie files
                errorBuilder: (context, error, stackTrace) {
                  // Provide a fallback widget when Lottie fails to load
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.animation, color: Colors.blue, size: 50),
                        SizedBox(height: 10),
                        Text('Animation not available'),
                        Text(
                          'Displaying fallback content instead',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
                frameBuilder: (context, child, composition) {
                  // Show loading indicator while animation is loading
                  if (composition == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Loading animation...'),
                        ],
                      ),
                    );
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