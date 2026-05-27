class BilanPage {
  final int? id;
  final int bilanId;
  final int pageNumber;
  final String filePath;

  BilanPage({
    this.id,
    required this.bilanId,
    required this.pageNumber,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bilan_id': bilanId,
      'page_number': pageNumber,
      'file_path': filePath,
    };
  }

  factory BilanPage.fromMap(Map<String, dynamic> map) {
    return BilanPage(
      id: map['id'] as int?,
      bilanId: map['bilan_id'] as int,
      pageNumber: map['page_number'] as int,
      filePath: map['file_path'] as String,
    );
  }
}
