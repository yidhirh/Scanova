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

  /// Ouvre ML Kit avec **import galerie activé** (multi-pages). L'utilisateur
  /// choisit une ou plusieurs images dans l'écran du scanner ; ML Kit applique
  /// le même pipeline que la caméra (détection des bords, recadrage, correction
  /// de perspective/orientation, amélioration) et propose la prévisualisation
  /// éditable. Renvoie toutes les pages traitées dans l'ordre, ou une liste
  /// vide si l'utilisateur annule / en cas d'erreur.
  Future<List<File>> scanDocuments({int pageLimit = 10}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.filter, // couleur nettoyée, cohérent avec la caméra
        pageLimit: pageLimit,
        isGalleryImport: true,
      ),
    );

    try {
      debugPrint('[DocumentScannerService] Ouverture du scanner (import galerie)…');
      final result = await scanner.scanDocument();
      final images = result.images;
      debugPrint('[DocumentScannerService] ${images.length} page(s) importée(s).');
      return images.map((p) => File(p)).toList();
    } catch (e) {
      debugPrint('[DocumentScannerService] Erreur import galerie : $e');
      return [];
    } finally {
      scanner.close();
    }
  }
}
