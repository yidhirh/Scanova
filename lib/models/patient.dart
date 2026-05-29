class Patient {
  final int? id;
  final String nom;
  final String prenom;
  final String dateNaissance;
  final String? groupeSanguin;
  final String? numeroCni;
  final String? numeroSecuriteSociale;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Patient({
    this.id,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    this.groupeSanguin,
    this.numeroCni,
    this.numeroSecuriteSociale,
    this.createdAt,
    this.updatedAt,
  });

  /// Âge en années révolues, calculé dynamiquement (jamais stocké, sinon
  /// il deviendrait périmé au prochain anniversaire).
  /// Retourne `null` si la date de naissance est absente, mal formée ou
  /// hors plage → l'appelant affiche alors "Âge inconnu".
  int? get age {
    final naissance = _parseIsoDate(dateNaissance);
    if (naissance == null) return null;

    final now = DateTime.now();
    var years = now.year - naissance.year;
    // Anniversaire pas encore passé cette année → on retire un an.
    // (un patient né le 31/12 n'a pas le même âge en janvier qu'en décembre).
    if (now.month < naissance.month ||
        (now.month == naissance.month && now.day < naissance.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  /// Parse une date ISO `YYYY-MM-DD` de façon stricte.
  /// On n'utilise PAS `DateTime.tryParse` directement : il normalise
  /// silencieusement les débordements (ex: `1958-13-45` deviendrait une
  /// date valide mais fausse au lieu de renvoyer null). On valide donc les
  /// plages, puis on vérifie par round-trip (attrape aussi le 31 février, etc.).
  static DateTime? _parseIsoDate(String iso) {
    if (iso.isEmpty) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null; // débordement normalisé par DateTime → date invalide.
    }
    return date;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'prenom': prenom,
      'date_naissance': dateNaissance,
      'groupe_sanguin': groupeSanguin,
      'numero_cni': numeroCni,
      'numero_securite_sociale': numeroSecuriteSociale,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      dateNaissance: map['date_naissance'] as String,
      groupeSanguin: map['groupe_sanguin'] as String?,
      numeroCni: map['numero_cni'] as String?,
      numeroSecuriteSociale: map['numero_securite_sociale'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}
