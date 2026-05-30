class BilanPage {
  final int? id;
  final int bilanId;
  final int pageNumber;
  final String filePath;

  /// Texte OCR propre à cette page (mode lignes/blocs). Nullable : pages
  /// antérieures à la fonctionnalité page-par-page (migration v4) ou OCR vide.
  /// Le texte concaténé de toutes les pages reste dans [Bilan.texteOcrBrut].
  final String? ocrText;

  BilanPage({
    this.id,
    required this.bilanId,
    required this.pageNumber,
    required this.filePath,
    this.ocrText,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bilan_id': bilanId,
      'page_number': pageNumber,
      'file_path': filePath,
      'ocr_text': ocrText,
    };
  }

  factory BilanPage.fromMap(Map<String, dynamic> map) {
    return BilanPage(
      id: map['id'] as int?,
      bilanId: map['bilan_id'] as int,
      pageNumber: map['page_number'] as int,
      filePath: map['file_path'] as String,
      ocrText: map['ocr_text'] as String?,
    );
  }
}
