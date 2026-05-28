import '../models/bilan.dart';
import '../models/valeur_biologique.dart';

/// Parser de bilans biologiques (étape 3 du BILAN_PARSER_BRIEF).
///
/// Approche : machine à états ligne par ligne, pas un seul gros regex.
/// L'OCR sera de toute façon imparfait → l'utilisateur corrige via formulaire
/// (étape 5). L'objectif ici est de pré-remplir au mieux, pas la perfection.
///
/// Toutes les valeurs retournées portent `bilanId: 0` (placeholder) — la DAO
/// [DatabaseHelper.insertBilan] écrase ce champ avec l'id généré du bilan
/// parent au moment de l'insertion.
class BilanParser {
  static Bilan parse(String texteOcr, int patientId) {
    final lignes = texteOcr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? categorieCourante;
    final valeurs = <ValeurBiologique>[];
    int ordre = 0;

    for (final ligne in lignes) {
      final cat = detecterCategorie(ligne);
      if (cat != null) {
        categorieCourante = cat;
        continue;
      }

      final valeur = parserLigneValeur(ligne, categorieCourante, ordre);
      if (valeur != null) {
        valeurs.add(valeur);
        ordre++;
        continue;
      }
      // Sinon : ligne ignorée (méthode, observation, en-tête labo, etc.)
    }

    return Bilan(
      patientId: patientId,
      valeurs: valeurs,
      dateExamen: extraireDate(texteOcr),
      laboratoire: extraireLaboratoire(texteOcr),
      texteOcrBrut: texteOcr,
      createdAt: DateTime.now(),
    );
  }

  // ── Catégories ────────────────────────────────────────────────────────────

  /// En-têtes de section observés sur les bilans des 3 laboratoires (brief).
  /// Clé = forme normalisée (majuscules, sans ponctuation), valeur = libellé final.
  static const Map<String, String> _categories = {
    'HEMATOLOGIE': 'Hématologie',
    'HÉMATOLOGIE': 'Hématologie',
    'BIOCHIMIE': 'Biochimie',
    'BIOCHIMIE SANGUINE': 'Biochimie',
    'BIOCHIMIE-HORMONOLOGIE': 'Biochimie',
    'BIOCHIMIEHORMONOLOGIE': 'Biochimie',
    'HORMONOLOGIE': 'Hormonologie',
    'TRANSAMINASES': 'transaminases',
    'HEMOSTASE': 'Hémostase',
    'HÉMOSTASE': 'Hémostase',
    'IONOGRAMME': 'Ionogramme',
    'IONOGRAMME SANGUIN': 'Ionogramme',
    'MARQUEURS TUMORAUX': 'Marqueurs tumoraux',
    'VITAMINES': 'Vitamines',
    'SEROLOGIE': 'Sérologie',
    'SÉROLOGIE': 'Sérologie',
    'SEROLOGIE INFLAMMATOIRE': 'Sérologie',
    'SÉROLOGIE INFLAMMATOIRE': 'Sérologie',
    'PARASITOLOGIE': 'Parasitologie',
    'PARASITOLOGIES DES SELLES': 'Parasitologie',
    'PARASITOLOGIE DES SELLES': 'Parasitologie',
    'MEDICAMENTS': 'Médicaments',
    'MÉDICAMENTS': 'Médicaments',
    // Sous-sections traitées comme catégories à part entière.
    'FORMULE NUMERATION SANGUINE FNS': 'Hématologie',
    'NUMERATION FORMULE SANGUINE FNS': 'Hématologie',
    'EQUILIBRE LEUCOCYTAIRE': 'Hématologie',
  };

  static String? detecterCategorie(String ligne) {
    // Une ligne de catégorie ne contient pas de chiffres (les valeurs en ont
    // toujours). Garde-fou contre les faux positifs type "BIOCHIMIE 03/03/24".
    if (RegExp(r'\d').hasMatch(ligne)) return null;

    // On retire ponctuation et accents légers, on majuscule, on collapse les
    // espaces. Doit matcher les clés de [_categories] tolérantes aux variantes.
    final norm = ligne
        .toUpperCase()
        .replaceAll(RegExp(r'[()\[\].,:;/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _categories[norm];
  }

  // ── Ligne de valeur ───────────────────────────────────────────────────────

  /// Unités rencontrées dans les bilans (brief). Ordre important : les motifs
  /// les plus spécifiques en premier (mg/dL avant g/dL, sinon "mg/dL" matche
  /// comme "g/dL" et laisse le "m" dans le nom).
  ///
  /// Tolérance OCR : `μ` est souvent rendu `u` (parfois `µ` U+00B5). Les
  /// exposants `10³` deviennent `10*3`, `10^3` ou `103`.
  static const String unitePattern =
      r'(?:'
      r'10\s*[*^]?\s*[36]\s*/\s*[uµμU][lL]'   // 10*3/uL, 10^6/μL, 103 /uL
      r'|10\s*[*^]?\s*[36]\s*/\s*m[lL]'        // 10*3/mL (variante)
      r'|[µμu]UI?\s*/\s*m[lL]'                 // µUI/mL, uIU/mL
      r'|[µμu]Ul?\s*/\s*m[lL]'                 // µUl/mL, uIU/mL
      r'|[µμu]g\s*/\s*d?[lL]'                  // µg/dL, ug/L
      r'|[µμu]mol\s*/\s*[lL]'                  // µmol/L
      r'|mg\s*/\s*d?[lL]'                      // mg/dL, mg/L
      r'|ng\s*/\s*m[lL]'                       // ng/mL
      r'|pg\s*/\s*m[lL]'                       // pg/mL
      r'|mmol\s*/\s*[lL]'                      // mmol/L
      r'|UI?\s*/\s*[lL]'                       // U/L, UI/L
      r'|g\s*/\s*d?[lL]'                       // g/L, g/dL
      r'|[fF][lL]'                            // fL, fl, FL
      r'|[sS]econdes?'
      r'|%|fL|pg|secondes?|mm'
      r')';

  /// Regex d'une ligne de valeur biologique :
  ///   NOM [séparateur] VALEUR UNITÉ [NORME]
  ///
  /// - Séparateur : ≥2 caractères parmi {espace, point, _}. Couvre les
  ///   "Glycémie........0.85" et les "Glycémie  0.85" (double espace).
  /// - Valeur : décimale (virgule OU point) ou entier. Marqueur `*` toléré
  ///   après (signal hors-norme du labo 1, on l'ignore — calculé via norme).
  /// - Unité : motif [_unitePattern].
  /// - Reste = norme (parsée par [parserNorme]).
  // 1: nom — 2: valeur — 3: unité — 4: reste (norme)
  // `*?` après la valeur = marqueur hors-norme labo 1, ignoré (recalculé).
  // Concaténation avec _unitePattern : pas d'interpolation possible dans une
  // raw string, et garder _unitePattern factorisé reste plus lisible que
  // de l'inliner ici.
  // ignore: prefer_interpolation_to_compose_strings
  static final RegExp regexValeur = RegExp(
    r'^(.+?)[\s._]{1,}(\d+(?:[.,]\d+)?)\s*\*?\s*('
    + unitePattern +
    r')\s*(.*)$',
  );

  static ValeurBiologique? parserLigneValeur(
    String ligne,
    String? categorie,
    int ordre,
  ) {
    final m = regexValeur.firstMatch(ligne);
    if (m == null) {
      return parserLigneQualitative(ligne, categorie, ordre);
    }

    final nom = nettoyerNom(m.group(1)!);
    if (nom.isEmpty) return null;

    final valeurStr = m.group(2)!.replaceAll(',', '.');
    final unite = normaliserUnite(m.group(3)!);
    final normeStr = m.group(4)?.trim() ?? '';

    final norme = parserNorme(normeStr);

    return ValeurBiologique(
      bilanId: 0, // placeholder, écrasé par insertBilan
      nom: nom,
      valeurNumerique: double.tryParse(valeurStr),
      unite: unite,
      normeMin: norme.min,
      normeMax: norme.max,
      normeTexte: norme.texte,
      categorie: categorie,
      ordre: ordre,
    );
  }

  /// Résultats qualitatifs (parasitologie : "Absence", "Présence") : pas de
  /// valeur numérique, pas d'unité. Stocké dans [ValeurBiologique.valeurTexte].
  static final RegExp regexQualitative = RegExp(
    r'^(.+?)[\s._]{2,}(Absence|Pr[ée]sence|N[ée]gatif|Positif)\.?$',
    caseSensitive: false,
  );

  static ValeurBiologique? parserLigneQualitative(
    String ligne,
    String? categorie,
    int ordre,
  ) {
    final m = regexQualitative.firstMatch(ligne);
    if (m == null) return null;

    final nom = nettoyerNom(m.group(1)!);
    if (nom.isEmpty) return null;

    return ValeurBiologique(
      bilanId: 0,
      nom: nom,
      valeurTexte: m.group(2)!.trim(),
      categorie: categorie,
      ordre: ordre,
    );
  }

  /// Nettoyage du nom d'analyse : retire les dots de remplissage en queue,
  /// les espaces multiples, et la coche `V`/`v` du labo 3 si elle est isolée
  /// en fin de nom (ex: "Glycémie V" → "Glycémie").
  static String nettoyerNom(String s) {
    return s
        .replaceAll(RegExp(r'[._]+$'), '')        // dots/underscores en queue
        .replaceAll(RegExp(r'\s+\b[Vv]\b\s*$'), '') // coche OCR (labo 3)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Normalise l'unité : collapse les espaces autour de `/`, harmonise `u`→`µ`
  /// pour les unités micro (µg, µmol, µUI), normalise les exposants OCR.
  static String normaliserUnite(String u) {
    var s = u.replaceAll(RegExp(r'\s+'), '');
    // 10*3/uL → 10³/µL (forme canonique), idem 10^6, 103
    s = s.replaceAllMapped(
      RegExp(r'10[*^]?([36])/([uµμU])([lL])'),
      (m) {
        final exp = m.group(1) == '3' ? '³' : '⁶';
        return '10$exp/µ${m.group(3)!.toUpperCase() == 'L' ? 'L' : m.group(3)!}';
      },
    );
    // ug/dL → µg/dL, umol/L → µmol/L, uUI/mL → µUI/mL
    s = s.replaceAllMapped(
      RegExp(r'\bu(g|mol|UI?)\b', caseSensitive: false),
      (m) => 'µ${m.group(1)}',
    );
    return s;
  }

  // ── Norme ─────────────────────────────────────────────────────────────────

  /// Parse une norme parmi 3 formes :
  /// - intervalle `0.70 - 1.10`  → (min, max)
  /// - seuil max  `< 2.00`       → (null, max)
  /// - seuil min  `> 0.35`       → (min, null)
  /// - sinon                     → texte libre conservé pour relecture humaine
  static ({double? min, double? max, String? texte}) parserNorme(String s) {
    s = s.trim().replaceAll(',', '.');
    if (s.isEmpty) return (min: null, max: null, texte: null);

    // Cas: "0.70 - 1.10" (tiret ASCII ou unicode – —)
    final intervalle = RegExp(r'(\d+(?:\.\d+)?)\s*[-–—]\s*(\d+(?:\.\d+)?)').firstMatch(s);
    if (intervalle != null) {
      return (
        min: double.tryParse(intervalle.group(1)!),
        max: double.tryParse(intervalle.group(2)!),
        texte: null,
      );
    }

    final seuilMax = RegExp(r'<\s*(\d+(?:\.\d+)?)').firstMatch(s);
    if (seuilMax != null) {
      return (min: null, max: double.tryParse(seuilMax.group(1)!), texte: null);
    }

    final seuilMin = RegExp(r'>\s*(\d+(?:\.\d+)?)').firstMatch(s);
    if (seuilMin != null) {
      return (min: double.tryParse(seuilMin.group(1)!), max: null, texte: null);
    }

    return (min: null, max: null, texte: s);
  }

  // ── Métadonnées du bilan ──────────────────────────────────────────────────

  /// Cherche en priorité `Prélèvement du : DD/MM/YYYY` (format observé sur
  /// les 3 labos). Fallback : première date `DD/MM/YYYY` du document.
  static DateTime? extraireDate(String texteOcr) {
    final prelevement = RegExp(
      r'[Pp]r[éeè]l[èeé]vement\s+du\s*:?\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})',
    ).firstMatch(texteOcr);
    if (prelevement != null) {
      return toDate(prelevement.group(1)!, prelevement.group(2)!, prelevement.group(3)!);
    }

    final anyDate = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})').firstMatch(texteOcr);
    if (anyDate != null) {
      return toDate(anyDate.group(1)!, anyDate.group(2)!, anyDate.group(3)!);
    }
    return null;
  }

  static DateTime? toDate(String d, String m, String y) {
    return DateTime.tryParse('$y-${m.padLeft(2, '0')}-${d.padLeft(2, '0')}');
  }

  /// Heuristique très simple : on cherche une ligne contenant "Dr " ou "LABO"
  /// dans les 10 premières lignes (en-tête du bilan). Pas d'engagement de
  /// qualité — l'utilisateur corrige via formulaire.
  static String? extraireLaboratoire(String texteOcr) {
    final lignes = texteOcr.split('\n').take(10);
    for (final ligne in lignes) {
      final l = ligne.trim();
      if (l.isEmpty) continue;
      if (RegExp(r'\b(Dr|DR|Docteur|LABO|Laboratoire)\b').hasMatch(l)) {
        return l;
      }
    }
    return null;
  }
}
