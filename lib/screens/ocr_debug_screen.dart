import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';

class OcrDebugScreen extends StatefulWidget {
  const OcrDebugScreen({super.key});

  @override
  State<OcrDebugScreen> createState() => _OcrDebugScreenState();
}

class _OcrDebugScreenState extends State<OcrDebugScreen> {
  final _ocrService = OcrService();
  final _picker = ImagePicker();

  bool _loading = false;
  String? _rawText;
  String? _structuredText;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;

    setState(() {
      _loading = true;
      _rawText = null;
      _structuredText = null;
    });

    final file = File(picked.path);

    // Les deux appels en parallèle sur la même image.
    final results = await Future.wait([
      _ocrService.extractTextFromImage(picked.path),
      _ocrService.extractStructuredText(file),
    ]);

    setState(() {
      _loading = false;
      _rawText = results[0].isEmpty ? '(aucun texte détecté)' : results[0];
      _structuredText = results[1].isEmpty ? '(aucun texte détecté)' : results[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug OCR'),
        backgroundColor: const Color(0xFFFDF6FD),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFDF6FD),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _pickAndProcess(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Caméra'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _pickAndProcess(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galerie'),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rawText == null)
            const Expanded(
              child: Center(
                child: Text(
                  'Prends une photo ou choisis depuis la galerie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    Expanded(child: _ResultPanel(title: 'OCR brut', text: _rawText!)),
                    const Divider(height: 24, thickness: 1.5),
                    Expanded(child: _ResultPanel(title: 'OCR reconstruit', text: _structuredText!)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2563EB),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
