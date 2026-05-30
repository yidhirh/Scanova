class DocumentPage {
  final int? id;
  final int documentId;
  final int pageNumber;
  final String filePath;

  /// Texte OCR propre à cette page (mode lignes/blocs). Nullable : pages
  /// antérieures à la fonctionnalité page-par-page (migration v4) ou OCR vide.
  final String? ocrText;

  DocumentPage({
    this.id,
    required this.documentId,
    required this.pageNumber,
    required this.filePath,
    this.ocrText,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'page_number': pageNumber,
      'file_path': filePath,
      'ocr_text': ocrText,
    };
  }

  factory DocumentPage.fromMap(Map<String, dynamic> map) {
    return DocumentPage(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      pageNumber: map['page_number'] as int,
      filePath: map['file_path'] as String,
      ocrText: map['ocr_text'] as String?,
    );
  }
}
