import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessingService {
  Future<List<String>> generateOcrVariants(String imagePath) async {
    final inputFile = File(imagePath);
    final bytes = await inputFile.readAsBytes();

    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception("Impossible de lire l'image.");
    }

    // Corrige l'orientation de certaines images caméra
    img.Image baseImage = img.bakeOrientation(decodedImage);

    // Évite les images trop petites
    if (baseImage.width < 1600) {
      baseImage = img.copyResize(
        baseImage,
        width: 1600,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Évite aussi les images trop lourdes
    if (baseImage.width > 2600) {
      baseImage = img.copyResize(
        baseImage,
        width: 2600,
        interpolation: img.Interpolation.cubic,
      );
    }

    final directory = await getTemporaryDirectory();

    final List<String> variants = [];

    // Variante 1 : gris + contraste léger
    final grayContrast = _grayAndContrast(
      baseImage,
      contrastFactor: 1.25,
    );
    variants.add(
      await _saveImage(directory, grayContrast, 'gray_contrast'),
    );

    // Variante 2 : noir/blanc seuil moyen
    final binary150 = _grayContrastAndBinarize(
      baseImage,
      threshold: 150,
      contrastFactor: 1.35,
    );
    variants.add(
      await _saveImage(directory, binary150, 'binary_150'),
    );

    // Variante 3 : noir/blanc seuil plus clair
    final binary175 = _grayContrastAndBinarize(
      baseImage,
      threshold: 175,
      contrastFactor: 1.35,
    );
    variants.add(
      await _saveImage(directory, binary175, 'binary_175'),
    );

    return variants;
  }

  img.Image _grayAndContrast(
      img.Image image, {
        required double contrastFactor,
      }) {
    final output = img.Image.from(image);

    for (int y = 0; y < output.height; y++) {
      for (int x = 0; x < output.width; x++) {
        final pixel = output.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        int gray = ((r * 0.299) + (g * 0.587) + (b * 0.114)).round();

        gray = _applyContrast(gray, contrastFactor);

        output.setPixelRgb(x, y, gray, gray, gray);
      }
    }

    return output;
  }

  img.Image _grayContrastAndBinarize(
      img.Image image, {
        required int threshold,
        required double contrastFactor,
      }) {
    final output = img.Image.from(image);

    for (int y = 0; y < output.height; y++) {
      for (int x = 0; x < output.width; x++) {
        final pixel = output.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        int gray = ((r * 0.299) + (g * 0.587) + (b * 0.114)).round();

        gray = _applyContrast(gray, contrastFactor);

        final value = gray > threshold ? 255 : 0;

        output.setPixelRgb(x, y, value, value, value);
      }
    }

    return output;
  }

  int _applyContrast(int gray, double contrastFactor) {
    final contrasted =
    (((gray / 255.0 - 0.5) * contrastFactor + 0.5) * 255).round();

    return contrasted.clamp(0, 255).toInt();
  }

  Future<String> _saveImage(
      Directory directory,
      img.Image image,
      String name,
      ) async {
    final outputPath =
        '${directory.path}/ocr_${name}_${DateTime.now().microsecondsSinceEpoch}.png';

    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(
      img.encodePng(image),
    );

    return outputFile.path;
  }
}