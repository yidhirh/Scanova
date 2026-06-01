import 'dart:io';

import 'package:flutter/material.dart';

import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService(); // caméra + import galerie : scanner ML Kit
  final OcrService _ocrService = OcrService(); // OCR principal : ML Kit hors ligne

  File? _selectedImage;
  String _extractedText = '';
  bool _isLoading = false;

  /// Caméra : scanner ML Kit (détection des bords + correction de perspective).
  Future<void> _scanWithCamera() async {
    final File? scanned = await _scannerService.scanDocument();
    if (scanned == null) return;
    await _runOcrOnImage(scanned);
  }

  /// Galerie : import via ML Kit (recadrage + perspective + amélioration),
  /// puis OCR sur l'image nettoyée (une seule page ici).
  Future<void> _pickFromGallery() async {
    final files = await _scannerService.scanDocuments(pageLimit: 1);
    if (files.isEmpty) return;
    await _runOcrOnImage(files.first);
  }

  Future<void> _runOcrOnImage(File image) async {
    try {
      setState(() {
        _selectedImage = image;
        _isLoading = true;
        _extractedText = '';
      });

      // OCR général : on garde seulement ML Kit pour les documents médicaux classiques.
      final text = await _ocrService.extractTextFromImage(image.path);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _extractedText = text.isEmpty
            ? 'Impossible d’extraire le texte. Veuillez réessayer avec une image plus claire.'
            : text;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _extractedText = 'Une erreur est survenue pendant l’extraction.';
      });

      debugPrint('OCR SCREEN ERROR: $e');
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanova - OCR'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage == null
                  ? const Text('Aucune image sélectionnée')
                  : Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanWithCamera,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Caméra'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo),
                    label: const Text('Galerie'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _extractedText.isEmpty
                          ? 'Le texte extrait apparaîtra ici.'
                          : _extractedText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
