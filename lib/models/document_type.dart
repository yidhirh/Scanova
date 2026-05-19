enum DocumentType {
  cni,
  chifa,
}

extension DocumentTypeExtension on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.cni:
        return 'CNI';
      case DocumentType.chifa:
        return 'Carte Chifa';
    }
  }

  String get description {
    switch (this) {
      case DocumentType.cni:
        return 'Carte Nationale d’Identité algérienne';
      case DocumentType.chifa:
        return 'Carte Chifa / assurance sociale';
    }
  }
}
