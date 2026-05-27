// Tests du parser de bilans (étape 4 du BILAN_PARSER_BRIEF).
// Texte OCR simulé inspiré des 3 formats de laboratoires algériens décrits
// dans le brief — pas de vraie OCR ici, juste des chaînes en dur.

import 'package:flutter_test/flutter_test.dart';
import 'package:scanova/services/bilan_parser.dart';

void main() {
  group('BilanParser - extraction ligne par ligne', () {
    test('intervalle de référence "0.70 - 1.10"', () {
      const ocr = '''
BIOCHIMIE
Glycémie à jeun.........0.85    g/L    0.70 - 1.10
''';
      final bilan = BilanParser.parse(ocr, 1);
      expect(bilan.valeurs!, hasLength(1));

      final v = bilan.valeurs!.first;
      expect(v.nom, 'Glycémie à jeun');
      expect(v.valeurNumerique, 0.85);
      expect(v.unite, 'g/L');
      expect(v.normeMin, 0.70);
      expect(v.normeMax, 1.10);
      expect(v.categorie, 'Biochimie');
      expect(v.estHorsNorme, isFalse);
    });

    test('seuil maximum "< 2.00"', () {
      const ocr = '''
BIOCHIMIE
Cholestérol total.......1.85    g/L    < 2.00
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.normeMin, isNull);
      expect(v.normeMax, 2.00);
      expect(v.estHorsNorme, isFalse);
    });

    test('seuil minimum "> 0.35"', () {
      const ocr = '''
BIOCHIMIE
HDL Cholestérol.........0.30    g/L    > 0.35
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.normeMin, 0.35);
      expect(v.normeMax, isNull);
      expect(v.estHorsNorme, isTrue, reason: '0.30 < seuil min 0.35');
    });

    test('virgule comme séparateur décimal (format FR)', () {
      const ocr = '''
BIOCHIMIE
Créatinine..............12,5    mg/L    7 - 13
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.valeurNumerique, 12.5);
      expect(v.normeMin, 7.0);
      expect(v.normeMax, 13.0);
    });

    test('marqueur "*" hors-norme du labo 1 est ignoré (recalculé)', () {
      const ocr = '''
BIOCHIMIE
Urée....................2.405 * g/L    0.15 - 0.45
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.valeurNumerique, 2.405);
      expect(v.estHorsNorme, isTrue, reason: '2.405 > max 0.45');
    });

    test('coche "V" du labo 3 est retirée du nom', () {
      const ocr = '''
HEMATOLOGIE
Hémoglobine V..........14.2    g/dL    13.0 - 17.0
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.nom, 'Hémoglobine');
    });

    test('résultat qualitatif "Absence" (parasitologie)', () {
      const ocr = '''
PARASITOLOGIES DES SELLES
Recherche de parasites............Absence
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      expect(v.nom, 'Recherche de parasites');
      expect(v.valeurNumerique, isNull);
      expect(v.valeurTexte, 'Absence');
      expect(v.categorie, 'Parasitologie');
    });
  });

  group('BilanParser - catégories', () {
    test('change de catégorie courante au fil des en-têtes', () {
      const ocr = '''
HEMATOLOGIE
Hémoglobine.............14.2    g/dL    13.0 - 17.0
BIOCHIMIE
Glycémie à jeun.........0.85    g/L    0.70 - 1.10
HORMONOLOGIE
TSH.....................2.10    µUI/mL    0.35 - 4.94
''';
      final valeurs = BilanParser.parse(ocr, 1).valeurs!;
      expect(valeurs, hasLength(3));
      expect(valeurs[0].categorie, 'Hématologie');
      expect(valeurs[1].categorie, 'Biochimie');
      expect(valeurs[2].categorie, 'Hormonologie');
    });

    test('une ligne contenant des chiffres ne peut pas être une catégorie', () {
      const ocr = '''
BIOCHIMIE 03/03/2024
Glycémie à jeun.........0.85    g/L    0.70 - 1.10
''';
      final v = BilanParser.parse(ocr, 1).valeurs!.first;
      // La catégorie reste null parce que "BIOCHIMIE 03/03/2024" n'est pas
      // détecté comme un en-tête (présence de chiffres) — garde-fou voulu.
      expect(v.categorie, isNull);
    });
  });

  group('BilanParser - métadonnées', () {
    test('extrait la date "Prélèvement du : DD/MM/YYYY"', () {
      const ocr = '''
LABORATOIRE Dr BOUDJEBLA
Prélèvement du : 03/03/2024

BIOCHIMIE
Glycémie à jeun.........0.85    g/L    0.70 - 1.10
''';
      final bilan = BilanParser.parse(ocr, 1);
      expect(bilan.dateExamen, DateTime(2024, 3, 3));
      expect(bilan.laboratoire, contains('BOUDJEBLA'));
    });

    test('fallback : première date trouvée si pas de "Prélèvement du"', () {
      const ocr = '''
Bilan du 15/06/2024
Glycémie à jeun.........0.85    g/L    0.70 - 1.10
''';
      expect(BilanParser.parse(ocr, 1).dateExamen, DateTime(2024, 6, 15));
    });

    test('texteOcrBrut est conservé tel quel (backup)', () {
      const ocr = 'TEXTE OCR BRUT ARBITRAIRE';
      expect(BilanParser.parse(ocr, 1).texteOcrBrut, ocr);
    });

    test('patientId est propagé', () {
      final bilan = BilanParser.parse('', 42);
      expect(bilan.patientId, 42);
      expect(bilan.valeurs, isEmpty);
    });
  });

  group('BilanParser - bilan complet (mini-Boudjebla)', () {
    test('parse un extrait réaliste multi-sections', () {
      // Inspiré du Labo 1 (Boudjebla, Tizi Ouzou) du brief :
      // - sections en MAJUSCULES
      // - marqueur `*` hors-norme
      // - intervalle classique et seuil `<`
      // - lignes "méthode" entre parenthèses → ignorées
      const ocr = '''
LABORATOIRE Dr BOUDJEBLA - Tizi Ouzou
Prélèvement du : 03/03/2024
Dossier N° 00428

BIOCHIMIE-HORMONOLOGIE
Glycémie à jeun.........0.85    g/L      0.70 - 1.10
(Héxokinase Cobas 6000)
Urée....................2.405 * g/L      0.15 - 0.45
Cholestérol total.......1.85    g/L      < 2.00

HEMATOLOGIE
Hémoglobine.............14.2    g/dL     13.0 - 17.0
''';

      final bilan = BilanParser.parse(ocr, 7);
      expect(bilan.patientId, 7);
      expect(bilan.dateExamen, DateTime(2024, 3, 3));
      expect(bilan.laboratoire, contains('BOUDJEBLA'));

      final valeurs = bilan.valeurs!;
      expect(valeurs.map((v) => v.nom).toList(), [
        'Glycémie à jeun',
        'Urée',
        'Cholestérol total',
        'Hémoglobine',
      ]);
      // Catégorie héritée du dernier en-tête vu.
      expect(valeurs[0].categorie, 'Biochimie');
      expect(valeurs[3].categorie, 'Hématologie');
      // L'ordre reflète la position de saisie (pour réaffichage fidèle).
      for (var i = 0; i < valeurs.length; i++) {
        expect(valeurs[i].ordre, i);
      }
      // Hors-norme calculé, pas lu depuis l'astérisque.
      expect(valeurs[1].estHorsNorme, isTrue);
      expect(valeurs[0].estHorsNorme, isFalse);
    });
  });
}
