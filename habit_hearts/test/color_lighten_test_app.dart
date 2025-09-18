import 'package:flutter/material.dart';
import 'widgets/color_lighten_test.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Lighten Test',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const ColorLightenTest(),
    );
  }
}