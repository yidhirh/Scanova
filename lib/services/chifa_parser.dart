import '../models/patient_data.dart';

class ChifaParser {
  static PatientData parse(String text) {
    final String normalizedText = _normalizeText(text);

    final List<String> lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final String? numSecu = _extractSocialSecurityNumber(text);
    final String? dateNaissance = _extractBirthDate(normalizedText);

    // Sur la Chifa, les labels sont en arabe (الإسم, اللقب, الميلاد).
    // ML Kit en mode "latin" ne lit pas bien l'arabe, donc on cherche
    // surtout le nom complet "PRENOM NOM" écrit en latin en bas de la carte.
    final Map<String, String?> names = _extractNamesFromLatinLine(lines);
    String? nom = names['nom'];
    String? prenom = names['prenom'];

    // Fallback : labels français au cas où
    nom ??= _extractValueAfterLabel(normalizedText, ['NOM', 'SURNAME']);
    prenom ??= _extractValueAfterLabel(
      normalizedText,
      ['PRENOM', 'PRÉNOM', 'PRENOMS', 'GIVEN NAME', 'GIVEN NAMES'],
    );

    final Set<String> aVerifier = {};
    if (nom == null || nom.isEmpty) aVerifier.add('nom');
    if (prenom == null || prenom.isEmpty) aVerifier.add('prenom');
    if (dateNaissance == null || dateNaissance.isEmpty) {
      aVerifier.add('dateNaissance');
    }
    if (numSecu == null || numSecu.isEmpty) aVerifier.add('numeroDocument');

    return PatientData(
      nom: nom ?? '',
      prenom: prenom ?? '',
      dateNaissance: dateNaissance ?? '',
      numeroDocument: numSecu ?? '',
      groupeSanguin: '',
      texteBrut: text,
      champsAVerifier: aVerifier,
    );
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }

  /// Sur la carte Chifa, le nom complet est imprimé en bas en latin
  /// sous la forme "PRENOM NOM" (ex: "MOHAND YAHIAOUI").
  /// On cherche une ligne contenant 2+ mots en majuscules.
  static Map<String, String?> _extractNamesFromLatinLine(List<String> lines) {
    String? nom;
    String? prenom;

    final RegExp wordRegex = RegExp(r'\b[A-Z]{3,}\b');

    // On parcourt les lignes et on cherche celle qui contient au moins
    // 2 mots majuscules qui ne sont pas des mots communs.
    for (final String line in lines) {
      final List<String> words = wordRegex
          .allMatches(line.toUpperCase())
          .map((m) => m.group(0)!)
          .where((w) => !_isCommonWord(w))
          .toList();

      if (words.length >= 2) {
        // Convention sur la Chifa : "PRENOM NOM"
        prenom = words[0];
        nom = words[1];
        break;
      }
    }

    // Si on n'a trouvé qu'un seul mot sur une ligne, on prend les 2 premiers
    // mots latins valides toutes lignes confondues.
    if (nom == null || prenom == null) {
      final List<String> allWords = [];
      for (final String line in lines) {
        for (final Match m in wordRegex.allMatches(line.toUpperCase())) {
          final String w = m.group(0)!;
          if (!_isCommonWord(w) && !allWords.contains(w)) {
            allWords.add(w);
          }
        }
      }
      if (allWords.length >= 2) {
        prenom ??= allWords[0];
        nom ??= allWords[1];
      }
    }

    return {'nom': nom, 'prenom': prenom};
  }

  static String? _extractValueAfterLabel(String text, List<String> labels) {
    for (final String label in labels) {
      final RegExp regex = RegExp(
        '$label\\s*[:\\-]?\\s*([A-Z][A-Z\\s\\-]{1,40})',
        caseSensitive: false,
      );
      final Match? match = regex.firstMatch(text);
      if (match != null) {
        final String? cleaned = _cleanName(match.group(1));
        if (cleaned != null && !_isCommonWord(cleaned)) {
          return cleaned;
        }
      }
    }
    return null;
  }

  static String? _extractBirthDate(String text) {
    final Set<DateTime> dates = {};

    // JJ/MM/AAAA, JJ.MM.AAAA, JJ-MM-AAAA
    final RegExp dmy = RegExp(
      r'(?<!\d)(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})(?!\d)',
    );
    for (final Match m in dmy.allMatches(text)) {
      final d = _parseValidDate(m.group(1)!, m.group(2)!, m.group(3)!);
      if (d != null) dates.add(d);
    }

    // AAAA.MM.JJ
    final RegExp ymd = RegExp(
      r'(?<!\d)(\d{4})[\/\-.](\d{2})[\/\-.](\d{2})(?!\d)',
    );
    for (final Match m in ymd.allMatches(text)) {
      final d = _parseValidDate(m.group(3)!, m.group(2)!, m.group(1)!);
      if (d != null) dates.add(d);
    }

    if (dates.isEmpty) return null;
    final sorted = dates.toList()..sort((a, b) => a.compareTo(b));
    final birth = sorted.first;
    return '${birth.day.toString().padLeft(2, '0')}/'
        '${birth.month.toString().padLeft(2, '0')}/'
        '${birth.year}';
  }

  static DateTime? _parseValidDate(String day, String month, String year) {
    final d = int.tryParse(day);
    final m = int.tryParse(month);
    final y = int.tryParse(year);
    if (d == null || m == null || y == null) return null;
    if (d < 1 || d > 31 || m < 1 || m > 12) return null;
    if (y < 1900 || y > DateTime.now().year) return null;
    try {
      final date = DateTime(y, m, d);
      if (date.day != d || date.month != m || date.year != y) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  /// N° sécu Chifa : format "XX XXXX XXXX XX" (10 chiffres groupés)
  /// ou collé "XXXXXXXXXX". On accepte 10 à 13 chiffres au total
  /// (parfois il y a un chiffre supplémentaire après).
  /// IMPORTANT : on travaille sur le texte BRUT (avec espaces) pour
  /// matcher les groupes, puis on enlève les espaces.
  static String? _extractSocialSecurityNumber(String rawText) {
    final String text = rawText.toUpperCase();

    // 1) Format groupé typique Chifa : "04 0890 0017 60" éventuellement
    //    suivi d'un autre chiffre.
    final RegExp groupedRegex = RegExp(
      r'(?<!\d)(\d{2})\s+(\d{4})\s+(\d{4})\s+(\d{2})(?:\s*(\d{1,2}))?',
    );
    final Match? grouped = groupedRegex.firstMatch(text);
    if (grouped != null) {
      final buffer = StringBuffer()
        ..write(grouped.group(1))
        ..write(grouped.group(2))
        ..write(grouped.group(3))
        ..write(grouped.group(4));
      if (grouped.group(5) != null) {
        buffer.write(grouped.group(5));
      }
      return buffer.toString();
    }

    // 2) Après un label connu
    final RegExp labelRegex = RegExp(
      r'(?:N[°O]?|NUMERO|SECU|SECURITE|ASSURE|MATRICULE|IMMATRICULATION)'
      r'\s*[:\-]?\s*([\d\s]{10,25})',
      caseSensitive: false,
    );
    final Match? labelMatch = labelRegex.firstMatch(text);
    if (labelMatch != null) {
      final digits = labelMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
      if (digits.length >= 10 && digits.length <= 15) {
        return digits;
      }
    }

    // 3) Séquence brute de 10 à 13 chiffres collés
    final RegExp collapsed = RegExp(r'(?<!\d)\d{10,13}(?!\d)');
    String? best;
    for (final Match m in collapsed.allMatches(text)) {
      final String cand = m.group(0)!;
      if (best == null || cand.length > best.length) best = cand;
    }
    return best;
  }

  static String? _cleanName(String? value) {
    if (value == null) return null;
    final cleaned = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    if (_isCommonWord(cleaned)) return null;
    return cleaned;
  }

  static bool _isCommonWord(String word) {
    final cw = word.toUpperCase().trim();
    const List<String> common = [
      'REPUBLIQUE', 'ALGERIENNE', 'DEMOCRATIQUE', 'POPULAIRE',
      'CARTE', 'CHIFA', 'ASSURANCE', 'SOCIALE', 'SECURITE',
      'CNAS', 'CASNOS', 'NATIONALE',
      'ASSURE', 'ASSURES', 'AYANT', 'DROIT',
      'DATE', 'NAISSANCE', 'NOM', 'PRENOM', 'PRENOMS',
      'NUMERO', 'MATRICULE', 'SEXE', 'NATIONALITE',
      'VALIDITE', 'VALABLE', 'JUSQU', 'IMMATRICULATION',
      'F', 'M', // sexe seul
    ];
    if (common.contains(cw)) return true;
    if (cw.split(' ').length > 4) return true;
    return false;
  }
}