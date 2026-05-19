import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/document_type.dart';
import '../models/patient_data.dart';
import '../services/chifa_parser.dart';
import '../services/document_image_preprocessor.dart';
import '../services/ocr_service.dart';
import 'patient_form_screen.dart';

class ChifaScanScreen extends StatefulWidget {
  const ChifaScanScreen({super.key});

  @override
  State<ChifaScanScreen> createState() => _ChifaScanScreenState();
}

class _ChifaScanScreenState extends State<ChifaScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final DocumentImagePreprocessor _preprocessor = DocumentImagePreprocessor();

  File? _image;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 2000,
      maxHeight: 2500,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
    });
  }

  Future<void> _processCard() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez d’abord prendre une photo.")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String prepared =
      await _preprocessor.prepareCardImage(_image!.path);
      final String text = await _ocrService.extractTextFromImage(prepared);

      final PatientData parsed = ChifaParser.parse(text).copyWith(
        sourceType: DocumentType.chifa,
      );

      if (!mounted) return;

      final result = await Navigator.push<PatientData>(
        context,
        MaterialPageRoute(
          builder: (_) => PatientFormScreen(initialData: parsed),
        ),
      );

      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur pendant l’analyse : $e")),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
      appBar: AppBar(title: const Text('Scanner Carte Chifa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Prenez une photo claire de la carte Chifa. Posez-la sur fond sombre, sans reflets.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              height: 240,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _image == null
                  ? const Text('Aucune image')
                  : Image.file(_image!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Caméra'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text('Galerie'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processCard,
              icon: _isProcessing
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isProcessing ? 'Analyse en cours...' : 'Analyser'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}