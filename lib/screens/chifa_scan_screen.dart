import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/document_type.dart';
import '../models/patient_data.dart';
import '../services/chifa_parser.dart';
import '../services/document_image_preprocessor.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import 'patient_form_screen.dart';

class ChifaScanScreen extends StatefulWidget {
  const ChifaScanScreen({super.key});

  @override
  State<ChifaScanScreen> createState() => _ChifaScanScreenState();
}

class _ChifaScanScreenState extends State<ChifaScanScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _backgroundColor = Color(0xFFFDF6FD);
  static const Color _textColor = Color(0xFF0F172A);

  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final DocumentImagePreprocessor _preprocessor = DocumentImagePreprocessor();
  final DocumentScannerService _scannerService = DocumentScannerService();

  File? _image;
  bool _isProcessing = false;
  String _currentStep = 'Pret pour la capture';

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
      _currentStep = 'Photo prete. Lancez l analyse.';
    });
  }

  /// Ouvre ML Kit Document Scanner pour capturer la carte Chifa avec
  /// détection automatique des bords et correction de perspective.
  Future<void> _scanCard() async {
    final File? scanned = await _scannerService.scanDocument();
    if (scanned == null) return;
    if (!mounted) return;
    setState(() {
      _image = scanned;
      _currentStep = 'Carte scannée. Lancez l\'analyse.';
    });
  }

  Future<void> _processCard() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez d'abord prendre une photo.")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 'Analyse OCR en cours...';
    });

    try {
      final String prepared =
          await _preprocessor.prepareCardImage(_image!.path);
      final String text = await _ocrService.extractTextFromImage(prepared);

      final PatientData parsed = ChifaParser.parse(text).copyWith(
        sourceType: DocumentType.chifa,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _currentStep = 'Extraction terminee';
      });

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PatientFormScreen(
            initialData: parsed,
            imagePath: _image!.path,
            ocrRawText: text,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStep = "Erreur pendant l'analyse";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur pendant l'analyse : $e")),
      );
    }
  }

  void _resetImage() {
    setState(() {
      _image = null;
      _isProcessing = false;
      _currentStep = 'Pret pour la capture';
    });
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Scanner Carte Chifa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _image == null ? _buildGuideCard() : _buildImagePreview(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _buildBottomActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: const BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Preremplissage par Chifa',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: _primaryColor,
              size: 52,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Capture de la carte Chifa',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Une seule prise suffit. Le scanner détecte automatiquement les bords de la carte et corrige la perspective.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildStep(
            number: '1',
            title: 'Scanner la carte',
            subtitle: 'Pointez vers la carte — les bords sont détectés automatiquement. Ou choisissez depuis la galerie.',
            icon: Icons.document_scanner,
          ),
          const SizedBox(height: 14),
          _buildStep(
            number: '2',
            title: 'Lancer l analyse',
            subtitle: "L'OCR extrait automatiquement nom, prenom et date.",
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 14),
          _buildStep(
            number: '3',
            title: 'Verifier les donnees',
            subtitle: 'Corrigez si besoin avant de confirmer.',
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: _primaryColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: _primaryColor,
            child: const Text(
              'Carte Chifa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Stack(
            children: [
              Image.file(
                _image!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: 260,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Analyse OCR en cours...',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.green.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Photo prete — lancez l analyse',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_image == null) {
      final bool busy = _isProcessing;
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: busy ? null : _scanCard,
              icon: const Icon(Icons.document_scanner),
              label: const Text(
                'Scanner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: busy ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text(
                'Galerie',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _resetImage,
            icon: const Icon(Icons.refresh),
            label: const Text('Reprendre'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processCard,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isProcessing ? 'Analyse...' : 'Analyser',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
