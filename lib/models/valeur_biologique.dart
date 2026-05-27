class ValeurBiologique {
  final int? id;
  final int bilanId;
  final String nom;
  final String? methode;

  // Valeur : numérique OU qualitative (ex: "Absence" pour parasitologie).
  final double? valeurNumerique;
  final String? valeurTexte;
  final String? unite;

  // Normes : intervalle (min+max), seuil max (< X), seuil min (> X)
  // ou texte libre si non parsable.
  final double? normeMin;
  final double? normeMax;
  final String? normeTexte;

  final String? categorie;
  final int ordre;

  ValeurBiologique({
    this.id,
    required this.bilanId,
    required this.nom,
    this.methode,
    this.valeurNumerique,
    this.valeurTexte,
    this.unite,
    this.normeMin,
    this.normeMax,
    this.normeTexte,
    this.categorie,
    required this.ordre,
  });

  /// Calculé à partir de [valeurNumerique] vs [normeMin] / [normeMax].
  /// Ne dépend pas des marqueurs visuels du bilan (astérisque, soulignement,
  /// surlignage) qui ne sont pas captés par l'OCR.
  bool get estHorsNorme {
    if (valeurNumerique == null) return false;
    if (normeMin != null && valeurNumerique! < normeMin!) return true;
    if (normeMax != null && valeurNumerique! > normeMax!) return true;
    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bilan_id': bilanId,
      'nom': nom,
      'methode': methode,
      'valeur_numerique': valeurNumerique,
      'valeur_texte': valeurTexte,
      'unite': unite,
      'norme_min': normeMin,
      'norme_max': normeMax,
      'norme_texte': normeTexte,
      'categorie': categorie,
      'ordre': ordre,
    };
  }

  factory ValeurBiologique.fromMap(Map<String, dynamic> map) {
    return ValeurBiologique(
      id: map['id'] as int?,
      bilanId: map['bilan_id'] as int,
      nom: map['nom'] as String,
      methode: map['methode'] as String?,
      valeurNumerique: (map['valeur_numerique'] as num?)?.toDouble(),
      valeurTexte: map['valeur_texte'] as String?,
      unite: map['unite'] as String?,
      normeMin: (map['norme_min'] as num?)?.toDouble(),
      normeMax: (map['norme_max'] as num?)?.toDouble(),
      normeTexte: map['norme_texte'] as String?,
      categorie: map['categorie'] as String?,
      ordre: map['ordre'] as int,
    );
  }
}
