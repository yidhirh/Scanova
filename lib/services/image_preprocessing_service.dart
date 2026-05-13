import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessingService {
  Future<String> preprocessForOcr(String imagePath) async {
    final inputFile = File(imagePath);
    final bytes = await inputFile.readAsBytes();

    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw Exception("Impossible de lire l'image.");
    }

    img.Image workingImage = originalImage;

    // 1. Agrandir l'image si elle est trop petite
    if (workingImage.width < 1200) {
      workingImage = img.copyResize(
        workingImage,
        width: 1200,
      );
    }

    // 2. Gris + contraste + noir/blanc
    workingImage = _prepareImageForOcr(workingImage);

    // 3. Sauvegarder l'image améliorée dans un fichier temporaire
    final directory = await getTemporaryDirectory();

    final outputPath =
        '${directory.path}/ocr_preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(
      img.encodeJpg(workingImage, quality: 100),
    );

    return outputFile.path;
  }

  img.Image _prepareImageForOcr(img.Image image) {
    const int threshold = 150;
    const double contrastFactor = 1.4;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Conversion en niveaux de gris
        int gray = ((r * 0.299) + (g * 0.587) + (b * 0.114)).round();

        // Amélioration simple du contraste
        gray = (((gray / 255.0 - 0.5) * contrastFactor + 0.5) * 255).round();
        gray = gray.clamp(0, 255);

        // Binarisation noir/blanc
        final value = gray > threshold ? 255 : 0;

        image.setPixelRgb(x, y, value, value, value);
      }
    }

    return image;
  }
}