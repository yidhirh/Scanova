import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      print('OCR START ML KIT');
      print('IMAGE PATH: $imagePath');

      final inputImage = InputImage.fromFilePath(imagePath);

      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);

      print('ML KIT RESULT: ${recognizedText.text}');

      return recognizedText.text.trim();
    } catch (e) {
      print('ML KIT OCR ERROR: $e');
      return '';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}