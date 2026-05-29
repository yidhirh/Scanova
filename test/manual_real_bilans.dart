/// Script de validation manuelle sur les 8 bilans réels.
///
/// Utilisation :
///   flutter test test/manual_real_bilans.dart --reporter expanded
///
/// Chaque bilan est chargé depuis test/fixtures/<nom>.txt (texte OCR brut).
/// Si le fichier est manquant → MISSING signalé, bilan ignoré.
///
/// Objectifs extraits du diagnostic externe (tableau brief) :
///   Kacher Triglycérides/Cholestérol  → ≥4  (HDL, LDL, Cholestérol total, Triglycérides)
///   FNS Mythic                         → ≥10 (FNS complète)
///   Biochimie+Iono+Lipides             → ≥8
///   Kacher avec valeurs *              → ≥6  (toutes + flag hors-norme)
///   AdomLAB                            → ≥6  (FNS)
///   Lipides+TSH                        → ≥3  (Cholestérol total + TSH + triglycérides)
///   Kacher FNS+VS                      → ≥12 (FNS complète + VS)
///   Kacher biochimie complet           → ≥8  (biochimie + hormones + CRP + Vit D)

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanova/services/bilan_parser.dart';

void main() {
  final specs = [
    _BilanSpec(
      id: 'kacher_lipides',
      label: 'Kacher Triglycérides/Cholestérol',
      file: 'test/fixtures/kacher_lipides.txt',
      minValeurs: 4,
    ),
    _BilanSpec(
      id: 'fns_mythic',
      label: 'FNS Mythic',
      file: 'test/fixtures/fns_mythic.txt',
      minValeurs: 10,
    ),
    _BilanSpec(
      id: 'biochimie_iono_lipides',
      label: 'Biochimie+Iono+Lipides',
      file: 'test/fixtures/biochimie_iono_lipides.txt',
      minValeurs: 8,
    ),
    _BilanSpec(
      id: 'kacher_star',
      label: 'Kacher avec valeurs *',
      file: 'test/fixtures/kacher_star.txt',
      minValeurs: 6,
    ),
    _BilanSpec(
      id: 'adomlab',
      label: 'AdomLAB',
      file: 'test/fixtures/adomlab.txt',
      minValeurs: 6,
    ),
    _BilanSpec(
      id: 'lipides_tsh',
      label: 'Lipides+TSH',
      file: 'test/fixtures/lipides_tsh.txt',
      minValeurs: 3,
    ),
    _BilanSpec(
      id: 'kacher_fns_vs',
      label: 'Kacher FNS+VS',
      file: 'test/fixtures/kacher_fns_vs.txt',
      minValeurs: 12,
    ),
    _BilanSpec(
      id: 'kacher_biochimie_complet',
      label: 'Kacher biochimie complet',
      file: 'test/fixtures/kacher_biochimie_complet.txt',
      minValeurs: 8,
    ),
  ];

  group('Validation sur bilans réels', () {
    for (final spec in specs) {
      test(spec.label, () {
        final f = File(spec.file);
        if (!f.existsSync()) {
          print('\n⚠️  MISSING: ${spec.file}');
          print('   → Ajoutez le texte OCR brut dans ce fichier pour valider ce bilan.\n');
          // Test marqué comme skip (pas fail) : fichier non fourni.
          markTestSkipped('Fixture manquante : ${spec.file}');
          return;
        }

        final ocr = f.readAsStringSync();
        final bilan = BilanParser.parse(ocr, 1);
        final valeurs = bilan.valeurs ?? [];

        _printBilanReport(spec, valeurs);

        // Assertion objectif.
        expect(
          valeurs.length,
          greaterThanOrEqualTo(spec.minValeurs),
          reason:
              '${spec.label} : ${valeurs.length} valeur(s) extraite(s), objectif ≥${spec.minValeurs}',
        );
      });
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

void _printBilanReport(
  _BilanSpec spec,
  List<dynamic> valeurs,
) {
  final ok = valeurs.length >= spec.minValeurs ? '✅' : '❌';
  print('\n────────────────────────────────────────');
  print('Bilan : ${spec.label}');
  print('Valeurs extraites : ${valeurs.length} / Objectif : ≥${spec.minValeurs} $ok');
  print('');
  for (final v in valeurs) {
    final val = v.valeurNumerique?.toString() ?? v.valeurTexte ?? '—';
    final u = v.unite ?? '';
    final cat = v.categorie != null ? '[${v.categorie}]' : '';
    final conf = '(conf:${v.confidence})';
    final abnormal = v.isMarkedAbnormal ? ' *LABO*' : '';
    final horsNorme = v.estHorsNorme ? ' ↑↓' : '';
    print('  ${v.nom.padRight(30)} $val ${u.padRight(12)} $cat $conf$abnormal$horsNorme');
  }
  print('────────────────────────────────────────\n');
}

class _BilanSpec {
  final String id;
  final String label;
  final String file;
  final int minValeurs;
  const _BilanSpec({
    required this.id,
    required this.label,
    required this.file,
    required this.minValeurs,
  });
}
