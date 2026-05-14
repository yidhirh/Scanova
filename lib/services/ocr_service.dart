import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath); //importation de l'image

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage); //appel de l'OCR

      print('ML KIT RESULT: ${recognizedText.text}'); //affichage du texte extrait

      return recognizedText.text.trim();
    } catch (e) {
      print('ML KIT OCR ERROR: $e'); ///gestion d'erreur pour l'OCR
      return '';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}