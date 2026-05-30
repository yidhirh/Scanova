import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Une page à imprimer : image scannée + son texte OCR (optionnel).
class PrintPage {
  final int number;
  final String imagePath;
  final String? ocrText;

  const PrintPage({
    required this.number,
    required this.imagePath,
    this.ocrText,
  });
}

/// Génère un PDF d'un document (toutes ses pages dans l'ordre, image + texte
/// OCR sous chaque image) et ouvre la feuille d'impression système.
///
/// Commun à tous les types de documents (bilan, ordonnance, radio, compte
/// rendu, autre) : le viewer fournit le titre, quelques lignes de métadonnées
/// métier (type/date, ou date de prélèvement/labo pour un bilan) et les pages.
class DocumentPrintService {
  static Future<void> printDocument({
    required String title,
    List<String> metaLines = const [],
    required List<PrintPage> pages,
  }) async {
    final doc = pw.Document();

    // Pré-charge les images (lecture disque hors du builder synchrone de pdf).
    final images = <int, pw.MemoryImage>{};
    for (final p in pages) {
      try {
        final file = File(p.imagePath);
        if (file.existsSync()) {
          final Uint8List bytes = await file.readAsBytes();
          images[p.number] = pw.MemoryImage(bytes);
        }
      } catch (e) {
        debugPrint('[DocumentPrintService] image illisible (${p.imagePath}) : $e');
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(title, metaLines),
          pw.SizedBox(height: 12),
          for (final p in pages) ..._pageBlock(p, images[p.number]),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: title.isEmpty ? 'document' : title,
    );
  }

  static pw.Widget _header(String title, List<String> metaLines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        if (metaLines.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          for (final line in metaLines)
            pw.Text(line, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, height: 1),
      ],
    );
  }

  static List<pw.Widget> _pageBlock(PrintPage p, pw.MemoryImage? image) {
    return [
      pw.SizedBox(height: 14),
      pw.Text(
        'Page ${p.number}',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      if (image != null)
        pw.Center(
          child: pw.Container(
            constraints: const pw.BoxConstraints(maxHeight: 420),
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        )
      else
        pw.Text('(image indisponible)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
      if (p.ocrText != null && p.ocrText!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Texte extrait (page ${p.number})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 4),
        pw.Text(p.ocrText!.trim(), style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
      ],
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.grey300, height: 1),
    ];
  }
}
