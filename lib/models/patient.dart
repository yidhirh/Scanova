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
