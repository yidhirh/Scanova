import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class DocumentImagePreprocessor {
  /// Prépare une photo de carte avant OCR.
  ///
  /// Pourquoi ?
  /// Le cadre affiché à l'écran est seulement un guide visuel. Sans crop,
  /// ML Kit et Tesseract analysent aussi le fond, la couverture, les ombres, etc.
  /// Ici on :
  /// 1) corrige l'orientation EXIF,
  /// 2) recadre la zone centrale où l'utilisateur place la carte,
  /// 3) agrandit l'image pour rendre les petits textes plus lisibles,
  /// 4) passe en niveaux de gris pour aider Tesseract.
  Future<String> prepareCardImage(String imagePath) async {
    try {
      final inputFile = File(imagePath);
      final bytes = await inputFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return imagePath;
      }

      final fixed = img.bakeOrientation(decoded);
      final cropped = _cropGuideArea(fixed);

      // Les textes sur CNI/Chifa sont petits. Un agrandissement aide Tesseract.
      final targetWidth = math.max(1600, cropped.width);
      final resized = img.copyResize(
        cropped,
        width: targetWidth,
        interpolation: img.Interpolation.cubic,
      );

      final grayscale = img.grayscale(resized);

      final parentPath = inputFile.parent.path;
      final outputPath = '$parentPath/scanova_card_preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(grayscale, quality: 95));

      return outputPath;
    } catch (e) {
      print('IMAGE PREPROCESSING ERROR: $e');
      return imagePath;
    }
  }

  img.Image _cropGuideArea(img.Image image) {
    final width = image.width;
    final height = image.height;
    final isPortrait = height >= width;

    late int cropWidth;
    late int cropHeight;
    late int x;
    late int y;

    if (isPortrait) {
      // Photo téléphone en portrait : la carte est normalement dans la partie
      // centrale/haute, comme le cadre affiché dans l'écran de scan.
      cropWidth = (width * 0.96).round();
      cropHeight = (cropWidth * 0.72).round();
      x = ((width - cropWidth) / 2).round();
      y = (height * 0.26).round();
    } else {
      // Si l'image sort en paysage, on prend une zone centrale large.
      cropWidth = (width * 0.90).round();
      cropHeight = (cropWidth * 0.64).round();
      x = ((width - cropWidth) / 2).round();
      y = ((height - cropHeight) / 2).round();
    }

    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + cropWidth > width) cropWidth = width - x;
    if (y + cropHeight > height) cropHeight = height - y;

    return img.copyCrop(
      image,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
  }
}
