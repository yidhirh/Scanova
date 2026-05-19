class PatientData {
  final String nom;
  final String prenom;
  final String dateNaissance;
  final String numeroDocument;
  final String groupeSanguin;
  final String texteBrut;

  final Set<String> champsAVerifier;

  const PatientData({
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.numeroDocument,
    this.groupeSanguin = '',
    required this.texteBrut,
    this.champsAVerifier = const {},
  });

  bool doitVerifier(String champ) {
    return champsAVerifier.contains(champ);
  }

  PatientData copyWith({
    String? nom,
    String? prenom,
    String? dateNaissance,
    String? numeroDocument,
    String? groupeSanguin,
    String? texteBrut,
    Set<String>? champsAVerifier,
  }) {
    return PatientData(
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      numeroDocument: numeroDocument ?? this.numeroDocument,
      groupeSanguin: groupeSanguin ?? this.groupeSanguin,
      texteBrut: texteBrut ?? this.texteBrut,
      champsAVerifier: champsAVerifier ?? this.champsAVerifier,
    );
  }

  @override
  String toString() {
    return '''
PatientData(
  nom: $nom,
  prenom: $prenom,
  dateNaissance: $dateNaissance,
  numeroDocument: $numeroDocument,
  groupeSanguin: $groupeSanguin,
  champsAVerifier: $champsAVerifier
)
''';
  }
}