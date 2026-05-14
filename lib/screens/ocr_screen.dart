import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker(); //importer des images depuis la galerie ou la caméra
  final OcrService _ocrService = OcrService(); //OCR

  File? _selectedImage;
  String _extractedText = '';
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2500,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true;
        _extractedText = '';
      });

      // Ici on utilise la méthode hybride :
      // ML Kit d'abord, puis Cloud si ML Kit est insuffisant.
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

      print('OCR SCREEN ERROR: $e');
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
                    onPressed: _isLoading
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Caméra'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
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