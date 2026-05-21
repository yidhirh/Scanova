class CardScan {
  final int? id;
  final int patientId;
  final String typeCarte; // 'CNI' ou 'CHIFA'
  final String imagePath;
  final String? ocrRawText;
  final DateTime? scannedAt;

  CardScan({
    this.id,
    required this.patientId,
    required this.typeCarte,
    required this.imagePath,
    this.ocrRawText,
    this.scannedAt,
  }) : assert(typeCarte == 'CNI' || typeCarte == 'CHIFA', 'typeCarte doit être CNI ou CHIFA');

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'type_carte': typeCarte,
      'image_path': imagePath,
      'ocr_raw_text': ocrRawText,
    };
  }

  factory CardScan.fromMap(Map<String, dynamic> map) {
    return CardScan(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      typeCarte: map['type_carte'] as String,
      imagePath: map['image_path'] as String,
      ocrRawText: map['ocr_raw_text'] as String?,
      scannedAt: map['scanned_at'] != null ? DateTime.parse(map['scanned_at'] as String) : null,
    );
  }
}
