class MedicalDocument {
  final int? id;
  final int patientId;
  final String typeDocument;
  final String titre;
  final String? description;
  final String filePath;
  final String? documentDate;
  final DateTime? createdAt;

  MedicalDocument({
    this.id,
    required this.patientId,
    required this.typeDocument,
    required this.titre,
    this.description,
    required this.filePath,
    this.documentDate,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'type_document': typeDocument,
      'titre': titre,
      'description': description,
      'file_path': filePath,
      'document_date': documentDate,
    };
  }

  factory MedicalDocument.fromMap(Map<String, dynamic> map) {
    return MedicalDocument(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      typeDocument: map['type_document'] as String,
      titre: map['titre'] as String,
      description: map['description'] as String?,
      filePath: map['file_path'] as String,
      documentDate: map['document_date'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }
}
