import 'document_page.dart';

class MedicalDocument {
  final int? id;
  final int patientId;
  final String typeDocument;
  final String titre;
  final String? description;
  final String? documentDate;
  final DateTime? createdAt;

  /// Pages du document (1 minimum en pratique).
  /// - `null`  = pas chargées (cas anormal car eager-loadées par [DatabaseHelper.getDocumentsByPatientId])
  /// - `[]`    = chargées mais aucune page (cas pathologique : doc orphelin)
  /// - liste non vide = cas nominal
  ///
  /// Non sérialisée dans [toMap] : les pages vivent dans la table `document_pages`
  /// et sont insérées séparément par [DatabaseHelper.insertMedicalDocument].
  final List<DocumentPage>? pages;

  MedicalDocument({
    this.id,
    required this.patientId,
    required this.typeDocument,
    required this.titre,
    this.description,
    this.documentDate,
    this.createdAt,
    this.pages,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'type_document': typeDocument,
      'titre': titre,
      'description': description,
      'document_date': documentDate,
    };
  }

  factory MedicalDocument.fromMap(
    Map<String, dynamic> map, {
    List<DocumentPage>? pages,
  }) {
    return MedicalDocument(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      typeDocument: map['type_document'] as String,
      titre: map['titre'] as String,
      description: map['description'] as String?,
      documentDate: map['document_date'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      pages: pages,
    );
  }
}
