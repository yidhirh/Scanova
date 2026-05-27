class DocumentPage {
  final int? id;
  final int documentId;
  final int pageNumber;
  final String filePath;

  DocumentPage({
    this.id,
    required this.documentId,
    required this.pageNumber,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'page_number': pageNumber,
      'file_path': filePath,
    };
  }

  factory DocumentPage.fromMap(Map<String, dynamic> map) {
    return DocumentPage(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      pageNumber: map['page_number'] as int,
      filePath: map['file_path'] as String,
    );
  }
}
