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

    nom = _extractValueAfterLabel(
      normalizedText,
      [
        'NOM',
        'SURNAME',
        'NAME',
      ],
    );

    prenom = _extractValueAfterLabel(
      normalizedText,
      [
        'PRENOM',
        'PRÉNOM',
        'GIVEN NAME',
        'GIVEN NAMES',
      ],
    );

    if (nom == null || prenom == null) {
      final Map<String, String?> mrzData = _extractFromMrz(lines);

      nom ??= mrzData['nom'];
      prenom ??= mrzData['prenom'];
    }

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
      'nom': _cleanName(nom),
      'prenom': _cleanName(prenom),
    };
  }

  static PatientData combineData(
      Map<String, String?> rectoData,
      Map<String, String?> versoData,
      ) {
    return PatientData(
      nom: versoData['nom'] ?? '',
      prenom: versoData['prenom'] ?? '',
      dateNaissance: rectoData['dateNaissance'] ?? '',
      numeroDocument: rectoData['numeroDocument'] ?? '',
      groupeSanguin: rectoData['groupeSanguin'] ?? '',
      texteBrut: '',
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

  static String? _extractDocumentNumber(String text) {
    final RegExp documentRegex = RegExp(r'\b\d{9}\b');
    final Match? match = documentRegex.firstMatch(text);

    if (match == null) return null;

    return match.group(0);
  }

  static String? _extractBirthDate(String text) {
    final List<String> dates = [];

    final RegExp separatedDateRegex = RegExp(
      r'\b(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})\b',
    );

    for (final Match match in separatedDateRegex.allMatches(text)) {
      final String day = match.group(1)!;
      final String month = match.group(2)!;
      final String year = match.group(3)!;

      final String? validDate = _formatValidDate(day, month, year);

      if (validDate != null) {
        dates.add(validDate);
      }
    }

    final RegExp compactDateRegex = RegExp(r'\b(\d{2})(\d{2})(\d{4})\b');

    for (final Match match in compactDateRegex.allMatches(text)) {
      final String day = match.group(1)!;
      final String month = match.group(2)!;
      final String year = match.group(3)!;

      final String? validDate = _formatValidDate(day, month, year);

      if (validDate != null) {
        dates.add(validDate);
      }
    }

    if (dates.isEmpty) return null;

    dates.sort((a, b) {
      final DateTime dateA = _parseDate(a);
      final DateTime dateB = _parseDate(b);

      return dateA.compareTo(dateB);
    });

    return dates.first;
  }

  static String? _formatValidDate(String day, String month, String year) {
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

      if (date.day != d || date.month != m || date.year != y) {
        return null;
      }

      final String formattedDay = d.toString().padLeft(2, '0');
      final String formattedMonth = m.toString().padLeft(2, '0');

      return '$formattedDay/$formattedMonth/$y';
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseDate(String date) {
    final List<String> parts = date.split('/');

    final int day = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    final int year = int.parse(parts[2]);

    return DateTime(year, month, day);
  }

  static String? _extractBloodGroup(String text) {
    final RegExp bloodRegex = RegExp(
      r'\b(AB|A|B|O)\s?([+\-])\b',
      caseSensitive: false,
    );

    final Match? match = bloodRegex.firstMatch(text);

    if (match == null) return null;

    final String group = match.group(1)!.toUpperCase();
    final String sign = match.group(2)!;

    return '$group$sign';
  }

  static String? _extractValueAfterLabel(
      String text,
      List<String> labels,
      ) {
    for (final String label in labels) {
      final RegExp regex = RegExp(
        '$label\\s*[:\\-]?\\s*([A-Z\\s\\-]{2,40})',
        caseSensitive: false,
      );

      final Match? match = regex.firstMatch(text);

      if (match != null) {
        final String? value = match.group(1);
        final String? cleaned = _cleanName(value);

        if (cleaned != null && !_isCommonWord(cleaned)) {
          return cleaned;
        }
      }
    }

    return null;
  }

  static Map<String, String?> _extractFromMrz(List<String> lines) {
    String? nom;
    String? prenom;

    for (final String line in lines) {
      String cleanLine = line
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('«', '<')
          .replaceAll('‹', '<');

      if (!cleanLine.contains('<<')) continue;

      cleanLine = cleanLine.replaceAll(RegExp(r'[^A-Z<]'), '');

      cleanLine = cleanLine.replaceFirst(RegExp(r'^ID[A-Z]{3}'), '');
      cleanLine = cleanLine.replaceFirst(RegExp(r'^DZA'), '');

      final List<String> parts = cleanLine.split('<<');

      if (parts.isNotEmpty) {
        final String possibleNom = parts[0].replaceAll('<', ' ').trim();

        if (possibleNom.length >= 2 && !_isCommonWord(possibleNom)) {
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

        if (possiblePrenom.length >= 2 && !_isCommonWord(possiblePrenom)) {
          prenom = possiblePrenom;
        }
      }

      if (nom != null || prenom != null) {
        break;
      }
    }

    return {
      'nom': _cleanName(nom),
      'prenom': _cleanName(prenom),
    };
  }

  static List<String> _extractPossibleLatinNames(List<String> lines) {
    final List<String> names = [];

    final RegExp wordRegex = RegExp(r'\b[A-Z]{2,}\b');

    for (final String line in lines) {
      final String upperLine = line.toUpperCase();

      for (final Match match in wordRegex.allMatches(upperLine)) {
        final String word = match.group(0)!;

        if (!_isCommonWord(word) && !names.contains(word)) {
          names.add(word);
        }
      }
    }

    return names;
  }

  static String? _cleanName(String? value) {
    if (value == null) return null;

    final String cleaned = value
        .toUpperCase()
        .replaceAll('<', ' ')
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return null;

    if (_isCommonWord(cleaned)) return null;

    return cleaned;
  }

  static bool _isCommonWord(String word) {
    final String cleanWord = word.toUpperCase().trim();

    final List<String> commonWords = [
      'REPUBLIQUE',
      'ALGERIENNE',
      'ALGERIEN',
      'DEMOCRATIQUE',
      'POPULAIRE',
      'CARTE',
      'NATIONALE',
      'IDENTITE',
      'IDENTIFICATION',
      'DATE',
      'NAISSANCE',
      'LIEU',
      'SEXE',
      'NATIONALITE',
      'ADRESSE',
      'SIGNATURE',
      'TITULAIRE',
      'VALABLE',
      'JUSQU',
      'DOCUMENT',
      'NUMERO',
      'GROUPE',
      'SANGUIN',
      'AUTHORITY',
      'ISSUED',
      'EXPIRES',
      'DZA',
      'ID',
      'DZ',
    ];

    if (commonWords.contains(cleanWord)) {
      return true;
    }

    if (cleanWord.split(' ').length > 4) {
      return true;
    }

    return false;
  }
}