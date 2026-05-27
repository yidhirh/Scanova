import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:meta/meta.dart';

// Alias interne pour alléger les signatures.
typedef _Element = ({Rect bbox, String text});

class OcrService {
  // Ajuster ces constantes après tests sur de vrais bilans.
  static const double _yClusteringTolerance = 0.5; // % de la hauteur de ligne
  static const String _columnSeparator = '    ';   // 4 espaces

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

  /// Reconstruit le texte en tenant compte de la disposition spatiale (colonnes).
  /// Utiliser cette méthode pour les bilans biologiques — l'autre retourne du
  /// texte désordonné quand le document est en colonnes.
  Future<String> extractStructuredText(File image) async {
    try {
      final inputImage = InputImage.fromFile(image);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final elements = <_Element>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          elements.add((bbox: line.boundingBox, text: line.text));
        }
      }

      if (elements.isEmpty) return '';
      return reconstructLines(elements);
    } catch (e) {
      debugPrint('ML KIT OCR ERROR (structured): $e');
      return '';
    }
  }

  /// Algorithme de reconstruction : regroupe les éléments par ligne logique
  /// (clustering Y), trie chaque groupe par X, et les joint avec [_columnSeparator].
  ///
  /// Exposé pour les tests unitaires uniquement — ne pas appeler en dehors des tests.
  @visibleForTesting
  static String reconstructLines(List<({Rect bbox, String text})> elements) {
    if (elements.isEmpty) return '';
    final clusters = _clusterByY(elements);
    return clusters.map(_clusterToLine).join('\n');
  }

  static List<List<_Element>> _clusterByY(List<_Element> elements) {
    final sorted = [...elements]
      ..sort((a, b) => a.bbox.center.dy.compareTo(b.bbox.center.dy));

    final clusters = <_LineCluster>[];
    for (final el in sorted) {
      if (clusters.isEmpty || !clusters.last.accepts(el)) {
        clusters.add(_LineCluster(el));
      } else {
        clusters.last.add(el);
      }
    }
    return clusters.map((c) => c.elements).toList();
  }

  static String _clusterToLine(List<_Element> cluster) {
    final sorted = [...cluster]
      ..sort((a, b) => a.bbox.left.compareTo(b.bbox.left));
    return sorted.map((e) => e.text).join(_columnSeparator);
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

class _LineCluster {
  final double centerY;
  final double height;
  final List<_Element> elements = [];

  _LineCluster(_Element first)
      : centerY = first.bbox.center.dy,
        height = first.bbox.height {
    elements.add(first);
  }

  bool accepts(_Element el) {
    return (el.bbox.center.dy - centerY).abs() < height * OcrService._yClusteringTolerance;
  }

  void add(_Element el) => elements.add(el);
}
