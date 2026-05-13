import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

import 'image_preprocessing_service.dart';

class OcrService {
  final ImagePreprocessingService _imagePreprocessingService =
  ImagePreprocessingService();

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      print('OCR START');
      print('IMAGE PATH ORIGINAL: $imagePath');

      // 1. Essayer d'abord l'image originale
      final originalText = await _runTesseract(imagePath);

      print('OCR ORIGINAL RESULT: $originalText');

      if (_isResultAcceptable(originalText)) {
        print('OCR BEST SOURCE: original image');
        return originalText.trim();
      }

      // 2. Si l'original est faible, générer plusieurs variantes améliorées
      final variants =
      await _imagePreprocessingService.generateOcrVariants(imagePath);

      String bestText = originalText;
      int bestScore = _scoreText(originalText);
      String bestSource = 'original image';

      for (final variantPath in variants) {
        print('OCR TRY VARIANT: $variantPath');

        final variantText = await _runTesseract(variantPath);
        final variantScore = _scoreText(variantText);

        print('OCR VARIANT SCORE: $variantScore');
        print('OCR VARIANT RESULT: $variantText');

        if (variantScore > bestScore) {
          bestScore = variantScore;
          bestText = variantText;
          bestSource = variantPath;
        }
      }

      print('OCR BEST SOURCE: $bestSource');
      print('OCR BEST SCORE: $bestScore');
      print('OCR BEST RESULT: $bestText');

      return bestText.trim();
    } catch (e) {
      print('OCR ERROR: $e');
      return '';
    }
  }

  Future<String> _runTesseract(String imagePath) async {
    final config = OCRConfig(
      language: 'fra',
      engine: OCREngine.tesseract,
    );

    final extractedText = await TesseractOcr.extractText(
      imagePath,
      config: config,
    );

    return extractedText.trim();
  }

  bool _isResultAcceptable(String text) {
    final cleanedText = text.trim();

    if (cleanedText.isEmpty) return false;

    final words = cleanedText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.length < 8) return false;

    final score = _scoreText(cleanedText);

    return score >= 30;
  }

  int _scoreText(String text) {
    final cleanedText = text.trim();

    if (cleanedText.isEmpty) return 0;

    final words = cleanedText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    final letters = RegExp(r'[A-Za-zÀ-ÿ]')
        .allMatches(cleanedText)
        .length;

    final digits = RegExp(r'[0-9]')
        .allMatches(cleanedText)
        .length;

    final suspiciousCharacters = RegExp(r'[^\w\sÀ-ÿ.,:;!?/\-()%]')
        .allMatches(cleanedText)
        .length;

    int score = 0;

    score += words.length * 4;
    score += letters;
    score += digits;
    score -= suspiciousCharacters * 5;

    return score;
  }
}