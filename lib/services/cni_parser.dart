import '../models/patient_data.dart';

class CniParser {
  static Map<String, String?> parseRecto(String text) {
    final String normalizedText = _normalizeText(text);

    return {
      'numeroDocument': _extractDocumentNumber(normalizedText),
      'dateNaissance': _extractBirthDate(normalizedText),
      'groupeSanguin': _extractBloodGroup(normalizedText),
    };
  }

  static Map<String, String?> parseVerso(String text) {
    final String normalizedText = _normalizeText(text);

    final List<String> lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? nom;
    String? prenom;

    // 1) On essaie d'abord la MRZ : c'est la source la plus fiable.
    final Map<String, String?> mrzData = _extractFromMrz(lines);
    nom = mrzData['nom'];
    prenom = mrzData['prenom'];

    // 2) Sinon, on cherche après les labels NOM / PRENOM.
    if (nom == null) {
      nom = _extractValueAfterLabel(normalizedText, ['NOM', 'SURNAME', 'NAME']);
    }
    if (prenom == null) {
      prenom = _extractValueAfterLabel(
        normalizedText,
        ['PRENOM', 'PRÉNOM', 'GIVEN NAME', 'GIVEN NAMES'],
      );
    }

    // 3) En dernier recours : les mots latins les plus longs.
    if (nom == null || prenom == null) {
      final List<String> possibleNames = _extractPossibleLatinNames(lines);

      if (nom == null && possibleNames.isNotEmpty) {
        nom = possibleNames[0];
      }
      if (prenom == null && possibleNames.length > 1) {
        prenom = possibleNames[1];
      }
    }

    return {
      'nom': _cleanName(nom, fromMrz: false),
      'prenom': _cleanName(prenom, fromMrz: false),
    };
  }

  static PatientData combineData(
      Map<String, String?> rectoData,
      Map<String, String?> versoData,
      ) {
    // On marque comme "à vérifier" les champs qu'on n'a pas pu extraire.
    final Set<String> aVerifier = {};

    final nom = versoData['nom'] ?? '';
    final prenom = versoData['prenom'] ?? '';
    final dateNaissance = rectoData['dateNaissance'] ?? '';
    final numeroDocument = rectoData['numeroDocument'] ?? '';
    final groupeSanguin = rectoData['groupeSanguin'] ?? '';

    if (nom.isEmpty) aVerifier.add('nom');
    if (prenom.isEmpty) aVerifier.add('prenom');
    if (dateNaissance.isEmpty) aVerifier.add('dateNaissance');
    if (numeroDocument.isEmpty) aVerifier.add('numeroDocument');
    if (groupeSanguin.isEmpty) aVerifier.add('groupeSanguin');

    return PatientData(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      numeroDocument: numeroDocument,
      groupeSanguin: groupeSanguin,
      texteBrut: '',
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

  /// N° CNI : 9 chiffres ISOLÉS (pas collés à d'autres chiffres).
  /// On évite ainsi de capturer un morceau de date compactée comme "01011990".
  static String? _extractDocumentNumber(String text) {
    // (?<!\d) et (?!\d) : pas de chiffre juste avant ou après.
    final RegExp documentRegex = RegExp(r'(?<!\d)\d{9}(?!\d)');

    // On prend tous les candidats et on garde le premier qui n'est pas
    // une date compactée (ex: 010119901 n'a que 9 chiffres mais bon).
    for (final Match match in documentRegex.allMatches(text)) {
      final String candidate = match.group(0)!;

      // On vérifie que ce n'est pas une date au format JJMMAAAAX
      if (!_looksLikeCompactDate(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  static bool _looksLikeCompactDate(String number) {
    if (number.length < 8) return false;

    // On regarde les 8 premiers chiffres : JJMMAAAA ?
    final day = int.tryParse(number.substring(0, 2));
    final month = int.tryParse(number.substring(2, 4));
    final year = int.tryParse(number.substring(4, 8));

    if (day == null || month == null || year == null) return false;

    return day >= 1 && day <= 31 &&
        month >= 1 && month <= 12 &&
        year >= 1900 && year <= DateTime.now().year;
  }

  /// Date de naissance : la plus ancienne date plausible (< année actuelle - 1).
  /// On exclut les dates trop récentes qui sont probablement des dates
  /// d'émission ou d'expiration de la carte.
  static String? _extractBirthDate(String text) {
    final Set<DateTime> dates = {};

    // Format 1 : JJ[sep]MM[sep]AAAA
    final RegExp dmyRegex = RegExp(
      r'(?<!\d)(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})(?!\d)',
    );
    for (final Match match in dmyRegex.allMatches(text)) {
      final DateTime? date = _parseValidDate(
        match.group(1)!,
        match.group(2)!,
        match.group(3)!,
      );
      if (date != null) dates.add(date);
    }

    // Format 2 : AAAA[sep]MM[sep]JJ (CNI algérienne récente)
    final RegExp ymdRegex = RegExp(
      r'(?<!\d)(\d{4})[\/\-.](\d{2})[\/\-.](\d{2})(?!\d)',
    );
    for (final Match match in ymdRegex.allMatches(text)) {
      final DateTime? date = _parseValidDate(
        match.group(3)!, // jour
        match.group(2)!, // mois
        match.group(1)!, // année
      );
      if (date != null) dates.add(date);
    }

    if (dates.isEmpty) return null;

    final List<DateTime> sorted = dates.toList()..sort((a, b) => a.compareTo(b));
    final DateTime birthDate = sorted.first;

    return '${birthDate.day.toString().padLeft(2, '0')}/'
        '${birthDate.month.toString().padLeft(2, '0')}/'
        '${birthDate.year}';
  }

  static DateTime? _parseValidDate(String day, String month, String year) {
    final int? d = int.tryParse(day);
    final int? m = int.tryParse(month);
    final int? y = int.tryParse(year);

    if (d == null || m == null || y == null) return null;

    final int currentYear = DateTime.now().year;
    if (d < 1 || d > 31) return null;
    if (m < 1 || m > 12) return null;
    if (y < 1900 || y > currentYear) return null;

    try {
      final DateTime date = DateTime(y, m, d);
      if (date.day != d || date.month != m || date.year != y) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  static String? _extractBloodGroup(String text) {
    final RegExp bloodRegex = RegExp(
      r'\b(AB|A|B|O)\s?([+\-])',
      caseSensitive: false,
    );

    final Match? match = bloodRegex.firstMatch(text);
    if (match == null) return null;

    return '${match.group(1)!.toUpperCase()}${match.group(2)!}';
  }

  static String? _extractValueAfterLabel(String text, List<String> labels) {
    for (final String label in labels) {
      final RegExp regex = RegExp(
        '$label\\s*[:\\-]?\\s*([A-Z][A-Z\\s\\-]{1,40})',
        caseSensitive: false,
      );

      final Match? match = regex.firstMatch(text);
      if (match != null) {
        final String? cleaned = _cleanName(match.group(1), fromMrz: false);
        if (cleaned != null && !_isCommonWord(cleaned)) {
          return cleaned;
        }
      }
    }

    return null;
  }

  /// MRZ algérienne (TD1, 3 lignes de 30 caractères).
  /// La ligne des noms est la 3e : NOM<<PRENOM<<<<...
  static Map<String, String?> _extractFromMrz(List<String> lines) {
    String? nom;
    String? prenom;

    // On regarde les lignes qui ressemblent à du MRZ : longues et avec '<<'.
    final List<String> mrzCandidates = lines.where((line) {
      final cleaned = line.toUpperCase().replaceAll(' ', '');
      return cleaned.length >= 20 && cleaned.contains('<<');
    }).toList();

    for (final String line in mrzCandidates) {
      String cleanLine = line
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('«', '<')
          .replaceAll('‹', '<')
          .replaceAll(RegExp(r'[^A-Z0-9<]'), '');

      // On enlève les préfixes type "IDDZA" ou "DZA" en début de ligne.
      cleanLine = cleanLine.replaceFirst(RegExp(r'^ID[A-Z]{3}'), '');
      cleanLine = cleanLine.replaceFirst(RegExp(r'^DZA'), '');

      // Une ligne de noms MRZ contient typiquement NOM<<PRENOM
      // et ne contient PAS de chiffres en grande quantité.
      final int digitCount = cleanLine.replaceAll(RegExp(r'[^0-9]'), '').length;
      if (digitCount > 3) continue; // c'est plutôt la ligne de dates/numéros

      final List<String> parts = cleanLine.split('<<');

      if (parts.isNotEmpty) {
        final String possibleNom = parts[0].replaceAll('<', ' ').trim();
        if (possibleNom.length >= 2 &&
            !_isCommonWord(possibleNom) &&
            RegExp(r'^[A-Z\s]+$').hasMatch(possibleNom)) {
          nom = possibleNom;
        }
      }

      if (parts.length > 1) {
        final String possiblePrenom = parts
            .sublist(1)
            .join(' ')
            .replaceAll('<', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (possiblePrenom.length >= 2 &&
            !_isCommonWord(possiblePrenom) &&
            RegExp(r'^[A-Z\s]+$').hasMatch(possiblePrenom)) {
          prenom = possiblePrenom;
        }
      }

      if (nom != null && prenom != null) break;
    }

    return {
      'nom': _cleanName(nom, fromMrz: true),
      'prenom': _cleanName(prenom, fromMrz: true),
    };
  }

  static List<String> _extractPossibleLatinNames(List<String> lines) {
    final List<String> names = [];

    // On exige au moins 3 lettres pour éviter les bruits.
    final RegExp wordRegex = RegExp(r'\b[A-Z]{3,}\b');

    for (final String line in lines) {
      final String upperLine = line.toUpperCase();

      for (final Match match in wordRegex.allMatches(upperLine)) {
        final String word = match.group(0)!;
        if (!_isCommonWord(word) && !names.contains(word)) {
          names.add(word);
        }
      }
    }

    // Les noms propres sont en général plus longs que le bruit.
    names.sort((a, b) => b.length.compareTo(a.length));

    return names;
  }

  /// Nettoyage des noms.
  /// fromMrz=true : on remplace les chiffres mal reconnus par des lettres
  /// (0→O, 1→I, 5→S) car la MRZ ne contient JAMAIS de chiffres dans le nom.
  /// fromMrz=false : on ne touche pas aux chiffres, ça abîme les vrais noms.
  static String? _cleanName(String? value, {required bool fromMrz}) {
    if (value == null) return null;

    String cleaned = value.toUpperCase().replaceAll('<', ' ');

    if (fromMrz) {
      cleaned = cleaned
          .replaceAll('0', 'O')
          .replaceAll('1', 'I')
          .replaceAll('5', 'S')
          .replaceAll('8', 'B');
    }

    cleaned = cleaned
        .replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return null;
    if (_isCommonWord(cleaned)) return null;

    return cleaned;
  }

  static bool _isCommonWord(String word) {
    final String cleanWord = word.toUpperCase().trim();

    const List<String> commonWords = [
      'REPUBLIQUE', 'ALGERIENNE', 'ALGERIEN', 'DEMOCRATIQUE', 'POPULAIRE',
      'CARTE', 'NATIONALE', 'IDENTITE', 'IDENTIFICATION',
      'DATE', 'NAISSANCE', 'LIEU', 'SEXE', 'NATIONALITE', 'ADRESSE',
      'SIGNATURE', 'TITULAIRE', 'VALABLE', 'JUSQU',
      'DOCUMENT', 'NUMERO', 'GROUPE', 'SANGUIN',
      'AUTHORITY', 'ISSUED', 'EXPIRES',
      'DZA', 'ID', 'DZ',
      'NOM', 'PRENOM', 'SURNAME',
    ];

    if (commonWords.contains(cleanWord)) return true;
    if (cleanWord.split(' ').length > 4) return true;

    return false;
  }
}