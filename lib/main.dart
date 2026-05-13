import 'package:flutter/material.dart';
import 'screens/ocr_screen.dart';

void main() {
  runApp(const ScanovaApp());
}

class ScanovaApp extends StatelessWidget {
  const ScanovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanova',
      debugShowCheckedModeBanner: false,
      home: const OcrScreen(),
    );
  }
}