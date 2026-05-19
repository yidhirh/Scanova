import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);

      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);

      debugPrint('ML KIT RESULT: ${recognizedText.text}');

      return recognizedText.text.trim();
    } catch (e) {
      debugPrint('ML KIT OCR ERROR: $e');
      return '';
    }
  }

  Future<Map<String, String>> scanBothSides(
      File rectoImage,
      File versoImage,
      ) async {
    final String rectoText = await extractTextFromImage(rectoImage.path);
    final String versoText = await extractTextFromImage(versoImage.path);

    return {
      'recto': rectoText,
      'verso': versoText,
    };
  }

  void dispose() {
    _textRecognizer.close();
  }
}