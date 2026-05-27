import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanova/services/ocr_service.dart';

// Helper local pour construire un élément sans répétition.
({Rect bbox, String text}) el(
  double left,
  double top,
  double width,
  double height,
  String text,
) =>
    (bbox: Rect.fromLTWH(left, top, width, height), text: text);

void main() {
  group('OcrService.reconstructLines - clustering spatial', () {
    test('liste vide → chaîne vide', () {
      expect(OcrService.reconstructLines([]), '');
    });

    test('1 seul élément → retourné tel quel', () {
      final result = OcrService.reconstructLines([
        el(0.0, 0.0, 200.0, 20.0, 'HEMATOLOGIE'),
      ]);
      expect(result, 'HEMATOLOGIE');
    });

    test('Cas 1 : 4 éléments au même Y → 1 ligne, colonnes triées par X', () {
      // Simule une ligne de bilan : nom | valeur | unité | norme
      // Les éléments sont donnés dans le désordre (comme ML Kit les retourne).
      final elements = [
        el(300.0, 10.0, 60.0, 20.0, '4.40'),
        el(0.0,   10.0, 150.0, 20.0, 'Globules rouges'),
        el(420.0, 10.0, 80.0, 20.0, '4 - 5.5'),
        el(370.0, 10.0, 45.0, 20.0, '10⁶/ml'),
      ];
      final result = OcrService.reconstructLines(elements);
      expect(result, 'Globules rouges    4.40    10⁶/ml    4 - 5.5');
    });

    test('Cas 2 : 4 éléments à Y très différents → 4 lignes séparées', () {
      final elements = [
        el(0.0, 10.0,  100.0, 20.0, 'Ligne A'),
        el(0.0, 50.0,  100.0, 20.0, 'Ligne B'),
        el(0.0, 90.0,  100.0, 20.0, 'Ligne C'),
        el(0.0, 130.0, 100.0, 20.0, 'Ligne D'),
      ];
      final result = OcrService.reconstructLines(elements);
      expect(result.split('\n'), ['Ligne A', 'Ligne B', 'Ligne C', 'Ligne D']);
    });

    test('Cas 3 : mix réaliste — 3 lignes × 4 colonnes → 3 lignes reconstruites', () {
      // Bilan simulé, éléments mélangés comme ML Kit les retournerait.
      final elements = [
        // Ligne 1 (Y ~ 10)
        el(0.0,   10.0, 150.0, 20.0, 'Globules rouges'),
        el(300.0, 12.0, 60.0,  20.0, '4.40'),
        el(370.0,  9.0, 45.0,  20.0, '10⁶/ml'),
        el(420.0, 11.0, 80.0,  20.0, '4 - 5.5'),
        // Ligne 2 (Y ~ 40)
        el(0.0,   40.0, 130.0, 20.0, 'Hémoglobine'),
        el(300.0, 38.0, 45.0,  20.0, '12.7'),
        el(370.0, 41.0, 45.0,  20.0, 'g/dL'),
        el(420.0, 39.0, 70.0,  20.0, '12 - 16'),
        // Ligne 3 (Y ~ 70)
        el(0.0,   70.0, 120.0, 20.0, 'Hématocrite'),
        el(300.0, 68.0, 45.0,  20.0, '38.7'),
        el(370.0, 72.0, 30.0,  20.0, '%'),
        el(420.0, 69.0, 70.0,  20.0, '36 - 54'),
      ];
      final lines = OcrService.reconstructLines(elements).split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], 'Globules rouges    4.40    10⁶/ml    4 - 5.5');
      expect(lines[1], 'Hémoglobine    12.7    g/dL    12 - 16');
      expect(lines[2], 'Hématocrite    38.7    %    36 - 54');
    });

    test('éléments donnés dans le désordre Y → triés correctement', () {
      // Donne Ligne B avant Ligne A — doit quand même sortir A puis B.
      final elements = [
        el(0.0, 50.0, 100.0, 20.0, 'Ligne B'),
        el(0.0, 10.0, 100.0, 20.0, 'Ligne A'),
      ];
      final result = OcrService.reconstructLines(elements);
      expect(result.split('\n'), ['Ligne A', 'Ligne B']);
    });
  });
}
