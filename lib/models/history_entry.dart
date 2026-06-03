// lib/models/history_entry.dart
//
// HistoryEntry — entrée unifiée de l'historique des numérisations.
//
// Agrège les trois sources de la base en un seul type pour l'affichage
// chronologique sur la Home (« Documents traités récemment ») et l'écran
// d'historique complet :
//   - card_scans        → kind = scan   (CNI / Chifa)
//   - medical_documents → kind = document (ordonnance, radio, compte rendu…)
//   - bilans            → kind = bilan
//
// Construit exclusivement depuis la requête UNION de
// [DatabaseHelper.getRecentHistory] : pas de table dédiée, pas de toMap().

/// Nature de l'entrée — détermine quelle table a produit la ligne et,
/// côté UI, quelle icône afficher et comment l'ouvrir.
enum HistoryKind { scan, document, bilan }

class HistoryEntry {
  /// id de la ligne dans sa table source (card_scans / medical_documents / bilans).
  final int id;
  final int patientId;
  final HistoryKind kind;

  /// Type métier brut :
  ///   - scan     → 'CNI' | 'CHIFA'
  ///   - document → type_document ('ordonnance', 'radio', 'compte rendu'…)
  ///   - bilan    → 'bilan'
  final String type;

  /// Titre affiché. `null` pour les scans et bilans (un libellé est dérivé
  /// dynamiquement par [displayTitle]).
  final String? titre;

  /// Horodatage de création (scanned_at / created_at).
  final DateTime? timestamp;

  final String patientNom;
  final String patientPrenom;

  const HistoryEntry({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.type,
    this.titre,
    this.timestamp,
    required this.patientNom,
    required this.patientPrenom,
  });

  String get patientFullName => '$patientNom $patientPrenom'.trim();

  /// Libellé affiché en titre de ligne. Utilise [titre] pour les documents
  /// médicaux ; dérive un libellé lisible pour les scans et bilans.
  String get displayTitle {
    switch (kind) {
      case HistoryKind.scan:
        return type == 'CNI' ? "Carte d'identité" : 'Carte Chifa';
      case HistoryKind.bilan:
        return 'Bilan biologique';
      case HistoryKind.document:
        return titre ?? 'Document';
    }
  }

  /// Clé de style utilisée par l'UI (icône + couleur), cohérente avec les
  /// autres écrans : 'cni', 'chifa', 'bilan', ou le type_document brut.
  String get styleKey {
    switch (kind) {
      case HistoryKind.scan:
        return type == 'CNI' ? 'cni' : 'chifa';
      case HistoryKind.bilan:
        return 'bilan';
      case HistoryKind.document:
        return type.toLowerCase();
    }
  }

  /// Construit une entrée depuis une ligne de la requête UNION de
  /// [DatabaseHelper.getRecentHistory]. La colonne `kind` est une chaîne
  /// ('scan' | 'document' | 'bilan').
  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    final kindStr = map['kind'] as String;
    final kind = switch (kindStr) {
      'scan' => HistoryKind.scan,
      'bilan' => HistoryKind.bilan,
      _ => HistoryKind.document,
    };
    return HistoryEntry(
      id: map['id'] as int,
      patientId: map['patient_id'] as int,
      kind: kind,
      type: map['type'] as String,
      titre: map['titre'] as String?,
      timestamp: _parseTimestamp(map['ts'] as String?),
      patientNom: (map['nom'] as String?) ?? '',
      patientPrenom: (map['prenom'] as String?) ?? '',
    );
  }

  /// Parse un horodatage SQLite. `CURRENT_TIMESTAMP` est stocké en **UTC**
  /// au format `YYYY-MM-DD HH:MM:SS` (sans marqueur de fuseau). On le marque
  /// donc comme UTC avant de le ramener en heure locale, sinon le calcul
  /// « il y a X » serait décalé du décalage horaire.
  static DateTime? _parseTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return null;
    final hasZone = ts.endsWith('Z') || ts.contains('+');
    final normalized = hasZone ? ts : '${ts.replaceFirst(' ', 'T')}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }
}
