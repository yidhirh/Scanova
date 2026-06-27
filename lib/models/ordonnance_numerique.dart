// lib/models/ordonnance_numerique.dart
//
// OrdonnanceNumerique — ordonnance saisie directement dans l'application
// (sans scan papier). Complète le module OCR, ne le remplace pas.
//
// Pas de table dédiée : l'ordonnance est persistée comme un
// [MedicalDocument] de type [typeDocument] ('ordonnance_numerique'),
// SANS page (aucune image), avec son contenu rendu en texte lisible dans
// `description` — ce qui la rend affichable par la visionneuse existante,
// cherchable par la recherche avancée et imprimable telle quelle.

import 'medical_document.dart';

/// Un médicament prescrit dans une ordonnance numérique.
class MedicamentPrescrit {
  final String nom;
  final String dosage;
  final String posologie;
  final String duree;

  const MedicamentPrescrit({
    required this.nom,
    this.dosage = '',
    this.posologie = '',
    this.duree = '',
  });
}

class OrdonnanceNumerique {
  /// Valeur persistée dans `medical_documents.type_document`.
  static const String typeDocument = 'ordonnance_numerique';

  final int patientId;
  final String nomPatient;

  /// Date de l'ordonnance au format ISO (YYYY-MM-DD).
  final String dateIso;
  final String nomMedecin;
  final List<MedicamentPrescrit> medicaments;
  final String remarques;

  const OrdonnanceNumerique({
    required this.patientId,
    required this.nomPatient,
    required this.dateIso,
    required this.nomMedecin,
    required this.medicaments,
    this.remarques = '',
  });

  String get _dateAffichee {
    final parts = dateIso.split('-');
    if (parts.length != 3) return dateIso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String get titre => 'Ordonnance numérique du $_dateAffichee';

  /// Rendu texte lisible de l'ordonnance, stocké dans
  /// `medical_documents.description` (affichage, recherche, impression).
  String toFormattedText() {
    final buffer = StringBuffer()
      ..writeln('Patient : $nomPatient')
      ..writeln('Médecin : $nomMedecin')
      ..writeln('Date : $_dateAffichee')
      ..writeln()
      ..writeln('Médicaments prescrits :');

    for (var i = 0; i < medicaments.length; i++) {
      final m = medicaments[i];
      buffer.writeln(
        '${i + 1}. ${m.nom}${m.dosage.isNotEmpty ? ' — ${m.dosage}' : ''}',
      );
      if (m.posologie.isNotEmpty) buffer.writeln('   Posologie : ${m.posologie}');
      if (m.duree.isNotEmpty) buffer.writeln('   Durée : ${m.duree}');
    }

    if (remarques.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Remarques / conseils :')
        ..writeln(remarques);
    }

    return buffer.toString().trimRight();
  }

  /// Conversion vers le document médical persisté. `pages: const []` :
  /// document purement numérique, aucune image associée.
  MedicalDocument toMedicalDocument() {
    return MedicalDocument(
      patientId: patientId,
      typeDocument: typeDocument,
      titre: titre,
      description: toFormattedText(),
      documentDate: dateIso,
      pages: const [],
    );
  }
}
