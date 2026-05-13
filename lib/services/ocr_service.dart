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

      // 1. Améliorer l'image avant OCR
      final preprocessedImagePath =
      await _imagePreprocessingService.preprocessForOcr(imagePath);

      print('IMAGE PATH PREPROCESSED: $preprocessedImagePath');

      // 2. Configuration OCR
      final config = OCRConfig(
        language: 'fra',
        engine: OCREngine.tesseract,
      );

      // 3. Envoyer l'image améliorée à Tesseract
      final extractedText = await TesseractOcr.extractText(
        preprocessedImagePath,
        config: config,
      );

      print('OCR RESULT: $extractedText');

      return extractedText.trim();
    } catch (e) {
      print('OCR ERROR: $e');
      return '';
    }
  }
}