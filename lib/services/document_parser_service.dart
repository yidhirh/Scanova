import '../models/patient_data.dart';

class DocumentParserService {
  static final RegExp _dateDayFirstRegex = RegExp(
    r'\b(0[1-9]|[12][0-9]|3[01])[\/\-.](0[1-9]|1[0-2])[\/\-.]((19|20)\d{2})\b',
  );

  static final RegExp _dateYearFirstRegex = RegExp(
    r'\b((19|20)\d{2})[\/\-.](0[1-9]|1[0-2])[\/\-.](0[1-9]|[12][0-9]|3[01])\b',
  );

  static final RegExp _mrzLineRegex = RegExp(r'^[A-Z0-9<]{20,44}$');
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');

  // ============================================================
  // CNI : RECTO + VERSO
  // ============================================================

  PatientData parseCniRectoVerso({
    required String rectoText,
    required String versoText,
  }) {
    final warnings = <String>{};

    final rectoNormalized = _normalizeText(rectoText);
    final versoNormalized = _normalizeText(versoText);

    final versoLines = _cleanLines(versoNormalized);
    final mrzLines = _extractMrzLines(versoLines);

    final numeroDocument = _extractCniNumber(rectoNormalized);
    final dateNaissance = _extractOldestPlausibleDate(rectoNormalized);
    final groupeSanguin = _extractBloodGroup(rectoNormalized);

    String nom = '';
    String prenom = '';

    final mrzName = _parseNameFromMrz(mrzLines);

    if (mrzName != null) {
      nom = mrzName.nom;
      prenom = mrzName.prenom;
    }

    if (nom.isEmpty) {
      nom = _valueAfterLatinLabels(versoLines, [
        'Nom',
        'Nom :',
        'Nom:',
        'NOM',
        'NOM DE FAMILLE',
        'SURNAME',
      ]);
    }

    if (prenom.isEmpty) {
      prenom = _valueAfterLatinLabels(versoLines, [
        'Prénom(s)',
        'Prénom(s):',
        'Prénom(s) :',
        'PRENOM',
        'PRÉNOM',
        'PRENOMS',
        'PRÉNOMS',
      ]);
    }

    if (nom.isEmpty) warnings.add('nom');
    if (prenom.isEmpty) warnings.add('prenom');
    if (dateNaissance.isEmpty) warnings.add('dateNaissance');
    if (numeroDocument.isEmpty) warnings.add('numeroDocument');
    if (groupeSanguin.isEmpty) warnings.add('groupeSanguin');

    return PatientData(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      numeroDocument: numeroDocument,
      groupeSanguin: groupeSanguin,
      texteBrut: '''
===== RECTO CNI =====
$rectoText

===== VERSO CNI =====
$versoText
''',
      champsAVerifier: warnings,
    );
  }

  // ============================================================
  // CNI : ancienne version en une seule image
  // Tu peux la garder pour compatibilité.
  // ============================================================

  PatientData parseCNI(String rawText) {
    final warnings = <String>{};

    final text = _normalizeText(rawText);
    final lines = _cleanLines(text);
    final mrzLines = _extractMrzLines(lines);

    String nom = '';
    String prenom = '';

    final mrzName = _parseNameFromMrz(mrzLines);

    if (mrzName != null) {
      nom = mrzName.nom;
      prenom = mrzName.prenom;
    }

    if (nom.isEmpty) {
      nom = _valueAfterLatinLabels(lines, [
        'NOM',
        'NOM DE FAMILLE',
        'SURNAME',
      ]);
    }

    if (prenom.isEmpty) {
      prenom = _valueAfterLatinLabels(lines, [
        'PRENOM',
        'PRÉNOM',
        'PRENOMS',
        'PRÉNOMS',
        'GIVEN NAME',
      ]);
    }

    if (nom.isEmpty) {
      nom = _valueAfterArabicLabels(lines, [
        'اللقب',
        'القب',
        'اسم العائلة',
        'الاسم العائلي',
      ]);
    }

    if (prenom.isEmpty) {
      prenom = _valueAfterArabicLabels(lines, [
        'الإسم الشخصي',
        'الاسم الشخصي',
        'الإسم',
        'الاسم',
      ]);
    }

    final dateNaissance = _extractBirthDate(lines, text, mrzLines);
    final numeroDocument = _extractCniNumber(text);
    final groupeSanguin = _extractBloodGroup(text);

    if (nom.isEmpty) warnings.add('nom');
    if (prenom.isEmpty) warnings.add('prenom');
    if (dateNaissance.isEmpty) warnings.add('dateNaissance');
    if (numeroDocument.isEmpty) warnings.add('numeroDocument');
    if (groupeSanguin.isEmpty) warnings.add('groupeSanguin');

    return PatientData(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      numeroDocument: numeroDocument,
      groupeSanguin: groupeSanguin,
      texteBrut: rawText,
      champsAVerifier: warnings,
    );
  }

  // ============================================================
  // CARTE CHIFA
  // ============================================================

  PatientData parseChifa(String rawText) {
    final warnings = <String>{};

    final text = _normalizeText(rawText);
    final lines = _cleanLines(text);

    String nom = '';
    String prenom = '';

    nom = _valueAfterLatinLabels(lines, [
      'NOM',
      'NOM DE FAMILLE',
    ]);

    prenom = _valueAfterLatinLabels(lines, [
      'PRENOM',
      'PRÉNOM',
      'PRENOMS',
      'PRÉNOMS',
    ]);

    if (nom.isEmpty) {
      nom = _valueAfterArabicLabels(lines, [
        'اللقب',
        'اسم العائلة',
        'الاسم العائلي',
      ]);
    }

    if (prenom.isEmpty) {
      prenom = _valueAfterArabicLabels(lines, [
        'الإسم الشخصي',
        'الاسم الشخصي',
        'الإسم',
        'الاسم',
      ]);
    }

    if (nom.isEmpty || prenom.isEmpty) {
      final fallbackName = _guessNameFromLines(lines);

      if (nom.isEmpty && fallbackName.nom.isNotEmpty) {
        nom = fallbackName.nom;
        warnings.add('nom');
      }

      if (prenom.isEmpty && fallbackName.prenom.isNotEmpty) {
        prenom = fallbackName.prenom;
        warnings.add('prenom');
      }
    }

    final dateNaissance = _extractBirthDate(lines, text, const []);

    final numeroDocument = _extractLongestNumber(
      text,
      minLength: 10,
      maxLength: 20,
    );

    if (nom.isEmpty) warnings.add('nom');
    if (prenom.isEmpty) warnings.add('prenom');
    if (dateNaissance.isEmpty) warnings.add('dateNaissance');
    if (numeroDocument.isEmpty) warnings.add('numeroDocument');

    return PatientData(
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      numeroDocument: numeroDocument,
      groupeSanguin: '',
      texteBrut: rawText,
      champsAVerifier: warnings,
    );
  }

  // ============================================================
  // NORMALISATION
  // ============================================================

  String _normalizeText(String input) {
    final normalizedDigits = _convertArabicIndicDigits(input);

    return normalizedDigits
        .replaceAll('\r', '\n')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim()
        .toUpperCase();
  }

  String _convertArabicIndicDigits(String input) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var result = input;

    map.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }

  List<String> _cleanLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
      !line.contains('=====') &&
          !line.contains('ML KIT OCR') &&
          !line.contains('TESSERACT ARABIC OCR') &&
          line != '[VIDE]',
    )
        .toList();
  }

  // ============================================================
  // MRZ
  // ============================================================

  List<String> _extractMrzLines(List<String> lines) {
    return lines
        .map((line) {
      return line
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'[^A-Z0-9<]'), '')
          .trim();
    })
        .where((line) => line.contains('<'))
        .where((line) => _mrzLineRegex.hasMatch(line))
        .toList();
  }

  _NameParts? _parseNameFromMrz(List<String> mrzLines) {
    for (final line in mrzLines.reversed) {
      if (!line.contains('<<')) continue;

      final parts = line.split('<<');

      if (parts.length < 2) continue;

      final nom = _cleanMrzName(parts[0]);
      final prenom = _cleanMrzName(parts.sublist(1).join(' '));

      if (nom.isNotEmpty && prenom.isNotEmpty) {
        return _NameParts(
          nom: nom,
          prenom: prenom,
        );
      }
    }

    return null;
  }

  String _cleanMrzName(String value) {
    return value
        .replaceAll('<', ' ')
        .replaceAll(RegExp(r'[^A-Z ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ============================================================
  // DATE
  // ============================================================

  String _extractBirthDate(
      List<String> lines,
      String text,
      List<String> mrzLines,
      ) {
    final nearLabel = _extractDateNearBirthLabel(lines);
    if (nearLabel.isNotEmpty) return nearLabel;

    final oldest = _extractOldestPlausibleDate(text);
    if (oldest.isNotEmpty) return oldest;

    if (mrzLines.isNotEmpty) {
      return _extractBirthDateFromMrz(mrzLines);
    }

    return '';
  }

  String _extractDateNearBirthLabel(List<String> lines) {
    final birthLabels = [
      'تاريخ الميلاد',
      'الميلاد',
      'DATE DE NAISSANCE',
      'NAISSANCE',
      'BIRTH',
    ];

    for (int i = 0; i < lines.length; i++) {
      final normalized = _removeAccents(lines[i]);

      final hasBirthLabel = birthLabels.any(
            (label) => normalized.contains(_removeAccents(label)),
      );

      if (!hasBirthLabel) continue;

      for (int j = i; j <= i + 2 && j < lines.length; j++) {
        final date = _extractFirstDateFromText(lines[j]);
        if (date.isNotEmpty) return date;
      }
    }

    return '';
  }

  String _extractFirstDateFromText(String text) {
    final dayFirst = _dateDayFirstRegex.firstMatch(text);

    if (dayFirst != null) {
      final day = dayFirst.group(1)!;
      final month = dayFirst.group(2)!;
      final year = dayFirst.group(3)!;

      return '$day/$month/$year';
    }

    final yearFirst = _dateYearFirstRegex.firstMatch(text);

    if (yearFirst != null) {
      final year = yearFirst.group(1)!;
      final month = yearFirst.group(3)!;
      final day = yearFirst.group(4)!;

      return '$day/$month/$year';
    }

    return '';
  }

  String _extractOldestPlausibleDate(String text) {
    final dates = <_ParsedDate>[];

    for (final match in _dateDayFirstRegex.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = int.tryParse(match.group(3) ?? '');

      if (day != null && month != null && year != null) {
        dates.add(
          _ParsedDate(
            day: day,
            month: month,
            year: year,
          ),
        );
      }
    }

    for (final match in _dateYearFirstRegex.allMatches(text)) {
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(3) ?? '');
      final day = int.tryParse(match.group(4) ?? '');

      if (day != null && month != null && year != null) {
        dates.add(
          _ParsedDate(
            day: day,
            month: month,
            year: year,
          ),
        );
      }
    }

    final currentYear = DateTime.now().year;

    final plausible = dates
        .where((date) => date.year >= 1900 && date.year <= currentYear)
        .where((date) => date.month >= 1 && date.month <= 12)
        .where((date) => date.day >= 1 && date.day <= 31)
        .toList();

    if (plausible.isEmpty) return '';

    plausible.sort((a, b) {
      final byYear = a.year.compareTo(b.year);
      if (byYear != 0) return byYear;

      final byMonth = a.month.compareTo(b.month);
      if (byMonth != 0) return byMonth;

      return a.day.compareTo(b.day);
    });

    return plausible.first.format();
  }

  String _extractBirthDateFromMrz(List<String> mrzLines) {
    for (final line in mrzLines) {
      final matches = RegExp(r'(\d{2})(\d{2})(\d{2})').allMatches(line);

      for (final match in matches) {
        final yy = int.tryParse(match.group(1) ?? '');
        final mm = int.tryParse(match.group(2) ?? '');
        final dd = int.tryParse(match.group(3) ?? '');

        if (yy == null || mm == null || dd == null) continue;
        if (mm < 1 || mm > 12 || dd < 1 || dd > 31) continue;

        final year = yy > 30 ? 1900 + yy : 2000 + yy;

        return _ParsedDate(
          day: dd,
          month: mm,
          year: year,
        ).format();
      }
    }

    return '';
  }

  // ============================================================
  // NUMÉROS
  // ============================================================

  String _extractCniNumber(String text) {
    final candidates = _numericCandidates(text)
        .where((number) => number.length == 9)
        .toList();

    if (candidates.isEmpty) return '';

    return candidates.first;
  }

  String _extractLongestNumber(
      String text, {
        required int minLength,
        required int maxLength,
      }) {
    final candidates = _numericCandidates(text)
        .where((number) => number.length >= minLength)
        .where((number) => number.length <= maxLength)
        .toList();

    candidates.sort((a, b) => b.length.compareTo(a.length));

    return candidates.isEmpty ? '' : candidates.first;
  }

  List<String> _numericCandidates(String text) {
    final regex = RegExp(r'\d(?:[\s\-]?\d){8,19}');

    return regex
        .allMatches(text)
        .map((match) => match.group(0) ?? '')
        .map((value) => value.replaceAll(RegExp(r'[\s\-]'), ''))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  // ============================================================
  // GROUPE SANGUIN
  // ============================================================

  String _extractBloodGroup(String text) {
    final normalized = text
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('0+', 'O+')
        .replaceAll('0-', 'O-')
        .replaceAll('RHESUS', 'RH');

    final regex = RegExp(r'(AB|A|B|O|0)(RH)?[+-]');

    final match = regex.firstMatch(normalized);

    if (match == null) return '';

    return match.group(0)!
        .replaceAll('RH', '')
        .replaceAll('0', 'O');
  }

  // ============================================================
  // NOM / PRÉNOM
  // ============================================================

  String _valueAfterLatinLabels(List<String> lines, List<String> labels) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final normalizedLine = _removeAccents(line);

      for (final label in labels) {
        final normalizedLabel = _removeAccents(label);

        if (!normalizedLine.contains(normalizedLabel)) continue;

        var value = _removeTextBeforeLabelValue(line, label);
        value = _cleanLatinName(value);

        if (_isValidNameFromLabel(value)) return value;

        final next = _nextValidNameLine(
          lines,
          i,
          arabic: false,
        );

        if (next.isNotEmpty) return next;
      }
    }

    return '';
  }

  String _valueAfterArabicLabels(List<String> lines, List<String> labels) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final label in labels) {
        if (!line.contains(label)) continue;

        var value = _removeTextBeforeLabelValue(line, label);

        value = _cleanArabicName(
          value,
          removeLabelWords: true,
        );

        if (_isValidNameFromLabel(value)) return value;

        final next = _nextValidNameLine(
          lines,
          i,
          arabic: true,
        );

        if (next.isNotEmpty) return next;
      }
    }

    return '';
  }

  String _removeTextBeforeLabelValue(String line, String label) {
    if (line.contains(':')) return line.split(':').last.trim();
    if (line.contains('：')) return line.split('：').last.trim();

    return line.replaceAll(label, ' ').trim();
  }

  String _nextValidNameLine(
      List<String> lines,
      int labelIndex, {
        required bool arabic,
      }) {
    for (int i = labelIndex + 1; i <= labelIndex + 3 && i < lines.length; i++) {
      final rawLine = lines[i];

      if (_looksLikeLabelOrNoise(rawLine)) continue;

      final cleaned = arabic
          ? _cleanArabicName(
        rawLine,
        removeLabelWords: true,
      )
          : _cleanLatinName(rawLine);

      if (_isValidNameFromLabel(cleaned)) return cleaned;
    }

    return '';
  }

  bool _looksLikeLabelOrNoise(String line) {
    final cleaned = line.trim();

    if (cleaned.isEmpty) return true;
    if (RegExp(r'\d').hasMatch(cleaned)) return true;
    if (_containsDocumentKeyword(cleaned)) return true;

    final noiseLabels = [
      'رقم',
      'التعريف',
      'الوطني',
      'تاريخ',
      'الميلاد',
      'الجنس',
      'ذكر',
      'أنثى',
      'الامضاء',
      'الإمضاء',
      'DATE',
      'NAISSANCE',
      'SEXE',
      'SIGNATURE',
    ];

    return noiseLabels.any((word) => cleaned.contains(word));
  }

  _NameParts _guessNameFromLines(List<String> lines) {
    final latinCandidates = lines
        .map(_cleanLatinName)
        .where(_isValidFullNameFallback)
        .where((line) => !_containsDocumentKeyword(line))
        .toList();

    if (latinCandidates.isNotEmpty) {
      return _splitFullName(latinCandidates.first);
    }

    final arabicCandidates = lines
        .map(
          (line) => _cleanArabicName(
        line,
        removeLabelWords: true,
      ),
    )
        .where(_isValidFullNameFallback)
        .where((line) => _arabicRegex.hasMatch(line))
        .where((line) => !_containsDocumentKeyword(line))
        .toList();

    if (arabicCandidates.isNotEmpty) {
      return _splitFullName(arabicCandidates.first);
    }

    return const _NameParts(
      nom: '',
      prenom: '',
    );
  }

  _NameParts _splitFullName(String fullName) {
    final cleaned = _arabicRegex.hasMatch(fullName)
        ? _cleanArabicName(
      fullName,
      removeLabelWords: true,
    )
        : _cleanLatinName(fullName);

    final tokens = cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();

    if (tokens.length >= 2) {
      return _NameParts(
        nom: tokens.first,
        prenom: tokens.skip(1).join(' '),
      );
    }

    return _NameParts(
      nom: cleaned,
      prenom: '',
    );
  }

  String _cleanLatinName(String value) {
    var result = value
        .replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý \-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final removableWords = [
      'NOM',
      'PRENOM',
      'PRÉNOM',
      'PRENOMS',
      'PRÉNOMS',
      'BENEFICIAIRE',
      'BÉNÉFICIAIRE',
      'ASSURE',
      'ASSURÉ',
      'SURNAME',
      'GIVEN',
      'NAME',
    ];

    for (final word in removableWords) {
      result = result.replaceAll(word, ' ').trim();
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanArabicName(
      String value, {
        required bool removeLabelWords,
      }) {
    var result = value
        .replaceAll(RegExp(r'[^\u0600-\u06FF\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (removeLabelWords) {
      final removableWords = [
        'اللقب',
        'الاسم',
        'الإسم',
        'العائلي',
        'الشخصي',
        'المستفيد',
        'المؤمن',
        'المؤمّن',
        'له',
      ];

      for (final word in removableWords) {
        result = result.replaceAll(word, ' ').trim();
      }
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isValidNameFromLabel(String value) {
    final cleaned = value.trim();

    if (cleaned.length < 2 || cleaned.length > 40) return false;
    if (RegExp(r'\d').hasMatch(cleaned)) return false;
    if (_containsDocumentKeyword(cleaned)) return false;

    final tokens = cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();

    if (tokens.isEmpty || tokens.length > 4) return false;
    if (tokens.any((token) => token.length < 2)) return false;

    final letterCount = RegExp(r'[A-ZÀ-ÖØ-Ý\u0600-\u06FF]')
        .allMatches(cleaned)
        .length;

    return letterCount >= 2;
  }

  bool _isValidFullNameFallback(String value) {
    if (!_isValidNameFromLabel(value)) return false;

    final tokens = value
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();

    if (tokens.length < 2) return false;

    final letterCount = RegExp(r'[A-ZÀ-ÖØ-Ý\u0600-\u06FF]')
        .allMatches(value)
        .length;

    if (letterCount > 25) return false;

    return true;
  }

  bool _containsDocumentKeyword(String value) {
    final normalized = _removeAccents(value);

    final keywords = [
      'REPUBLIQUE',
      'ALGERIENNE',
      'DEMOCRATIQUE',
      'POPULAIRE',
      'CARTE',
      'NATIONALE',
      'IDENTITE',
      'IDENTIFICATION',
      'CHIFA',
      'SECURITE',
      'SOCIALE',
      'CNAS',
      'CASNOS',
      'DATE',
      'NAISSANCE',
      'SIGNATURE',
      'VALABLE',
      'JUSQU',
      'MINISTERE',
      'ML',
      'KIT',
      'OCR',
      'TESSERACT',
      'الجمهورية',
      'الجمه',
      'جزائرية',
      'الجزائرية',
      'الجز',
      'ائرية',
      'الديمقراطية',
      'الشعبية',
      'بطاقة',
      'التعريف',
      'الوطنية',
      'الشفاء',
      'الضمان',
      'الاجتماعي',
      'تاريخ',
      'الميلاد',
      'الجنس',
      'ذكر',
      'أنثى',
      'الامضاء',
      'الإمضاء',
      'رقم',
    ];

    return keywords.any(normalized.contains);
  }

  String _removeAccents(String input) {
    return input
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ë', 'E')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ä', 'A')
        .replaceAll('Î', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Ô', 'O')
        .replaceAll('Ö', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('Û', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C');
  }
}

class _NameParts {
  final String nom;
  final String prenom;

  const _NameParts({
    required this.nom,
    required this.prenom,
  });
}

class _ParsedDate {
  final int day;
  final int month;
  final int year;

  const _ParsedDate({
    required this.day,
    required this.month,
    required this.year,
  });

  String format() {
    final formattedDay = day.toString().padLeft(2, '0');
    final formattedMonth = month.toString().padLeft(2, '0');

    return '$formattedDay/$formattedMonth/$year';
  }
}