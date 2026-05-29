import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScannerService {
  /// Ouvre le scanner ML Kit Document Scanner, laisse l'utilisateur
  /// numériser un ou plusieurs pages, et retourne le chemin de la première
  /// image traitée (recadrée + corrigée par le SDK).
  ///
  /// Retourne `null` si l'utilisateur annule ou si une erreur survient.
  Future<File?> scanDocument() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: false,
      ),
    );

    try {
      debugPrint('[DocumentScannerService] Ouverture du scanner ML Kit…');
      final result = await scanner.scanDocument();

      final images = result.images;
      if (images.isEmpty) {
        debugPrint('[DocumentScannerService] Annulation — aucune image retournée.');
        return null;
      }

      final path = images.first;
      debugPrint('[DocumentScannerService] Image scannée : $path');
      return File(path);
    } catch (e) {
      debugPrint('[DocumentScannerService] Erreur scanner : $e');
      return null;
    } finally {
      scanner.close();
    }
  }
}
