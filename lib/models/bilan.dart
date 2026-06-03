import 'bilan_page.dart';
import 'valeur_biologique.dart';

class Bilan {
  final int? id;
  final int patientId;
  final DateTime? dateExamen;
  final String? laboratoire;
  final String? medecinPrescripteur;
  final String? numeroDossier;
  final String? texteOcrBrut;
  final DateTime? createdAt;

  /// Valeurs biologiques du bilan.
  /// - `null`  = pas encore chargées depuis la DB (cas de [DatabaseHelper.getBilansByPatientId]
  ///   qui ne fait pas la jointure pour rester rapide).
  /// - `[]`    = chargées mais aucune valeur en base.
  /// - liste non vide = chargées (cas de [DatabaseHelper.getBilanById]).
  ///
  /// Non sérialisée dans [toMap] : les valeurs vivent dans la table
  /// `valeurs_biologiques` et sont insérées séparément par [DatabaseHelper.insertBilan].
  final List<ValeurBiologique>? valeurs;

  /// Pages du bilan scanné (peut être multi-page : bilan biologique souvent sur 2-5 pages).
  /// Même sémantique de chargement que [valeurs] :
  /// - `null`  = pas chargées (cas de [DatabaseHelper.getBilansByPatientId]).
  /// - `[]`    = chargées mais aucune page (cas pathologique).
  /// - liste non vide = chargées (cas de [DatabaseHelper.getBilanById]).
  ///
  /// Non sérialisée dans [toMap] : les pages vivent dans la table `bilan_pages`.
  final List<BilanPage>? pages;

  Bilan({
    this.id,
    required this.patientId,
    this.dateExamen,
    this.laboratoire,
    this.medecinPrescripteur,
    this.numeroDossier,
    this.texteOcrBrut,
    this.createdAt,
    this.valeurs,
    this.pages,
  });

  Bilan copyWith({
    int? id,
    int? patientId,
    DateTime? dateExamen,
    String? laboratoire,
    String? medecinPrescripteur,
    String? numeroDossier,
    String? texteOcrBrut,
    DateTime? createdAt,
    List<ValeurBiologique>? valeurs,
    List<BilanPage>? pages,
  }) {
    return Bilan(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      dateExamen: dateExamen ?? this.dateExamen,
      laboratoire: laboratoire ?? this.laboratoire,
      medecinPrescripteur: medecinPrescripteur ?? this.medecinPrescripteur,
      numeroDossier: numeroDossier ?? this.numeroDossier,
      texteOcrBrut: texteOcrBrut ?? this.texteOcrBrut,
      createdAt: createdAt ?? this.createdAt,
      valeurs: valeurs ?? this.valeurs,
      pages: pages ?? this.pages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'date_examen': dateExamen?.toIso8601String(),
      'laboratoire': laboratoire,
      'medecin_prescripteur': medecinPrescripteur,
      'numero_dossier': numeroDossier,
      'texte_ocr_brut': texteOcrBrut,
    };
  }

  factory Bilan.fromMap(
    Map<String, dynamic> map, {
    List<ValeurBiologique>? valeurs,
    List<BilanPage>? pages,
  }) {
    return Bilan(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      dateExamen: map['date_examen'] != null
          ? DateTime.parse(map['date_examen'] as String)
          : null,
      laboratoire: map['laboratoire'] as String?,
      medecinPrescripteur: map['medecin_prescripteur'] as String?,
      numeroDossier: map['numero_dossier'] as String?,
      texteOcrBrut: map['texte_ocr_brut'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      valeurs: valeurs,
      pages: pages,
    );
  }
}
