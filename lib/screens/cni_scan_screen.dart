import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/document_type.dart';
import '../models/patient_data.dart';
import '../services/cni_parser.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import 'patient_form_screen.dart';

class CniScanScreen extends StatefulWidget {
  const CniScanScreen({super.key});

  @override
  State<CniScanScreen> createState() => _CniScanScreenState();
}

class _CniScanScreenState extends State<CniScanScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _backgroundColor = Color(0xFFFDF6FD);
  static const Color _textColor = Color(0xFF0F172A);

  File? _rectoImage;
  File? _versoImage;

  bool _isCapturing = false;
  bool _isProcessing = false;

  String _currentStep = 'Prêt pour la capture';

  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final DocumentScannerService _scannerService = DocumentScannerService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<XFile?> _takePhoto() async {
    return await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2200,
      maxHeight: 2200,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<XFile?> _pickFromGallery() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2200,
      maxHeight: 2200,
    );
  }

  Future<void> _pickGallerySequential() async {
    if (_isCapturing || _isProcessing) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = false;
      _rectoImage = null;
      _versoImage = null;
      _currentStep = 'Sélection du recto...';
    });

    try {
      final XFile? rectoPhoto = await _pickFromGallery();

      if (rectoPhoto == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _currentStep = 'Sélection annulée';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _rectoImage = File(rectoPhoto.path);
        _currentStep = 'Recto sélectionné. Choisissez le verso...';
      });

      _showSuccessMessage('Recto sélectionné');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      setState(() => _currentStep = 'Sélection du verso...');

      final XFile? versoPhoto = await _pickFromGallery();

      if (versoPhoto == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _currentStep = 'Verso annulé. Veuillez recommencer.';
        });
        _showErrorDialog(
          'Sélection du verso annulée. Veuillez recommencer pour choisir les deux faces.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _versoImage = File(versoPhoto.path);
        _isCapturing = false;
        _currentStep = 'Deux faces sélectionnées. Prêt pour l\'extraction.';
      });

      _showSuccessMessage('Verso sélectionné');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isProcessing = false;
        _currentStep = 'Erreur pendant la sélection';
      });
      _showErrorDialog('Erreur lors de la sélection : $e');
    }
  }

  /// Ouvre ML Kit Document Scanner deux fois : d'abord pour le recto, puis
  /// pour le verso. Chaque scan bénéficie du recadrage et de la correction de
  /// perspective automatiques du SDK.
  Future<void> _scanSequential() async {
    if (_isCapturing || _isProcessing) return;

    setState(() {
      _isCapturing = true;
      _rectoImage = null;
      _versoImage = null;
      _currentStep = 'Scan du recto…';
    });

    try {
      final File? recto = await _scannerService.scanDocument();
      if (recto == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _currentStep = 'Scan annulé';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _rectoImage = recto;
        _currentStep = 'Recto scanné. Scannez maintenant le verso…';
      });
      _showSuccessMessage('Recto scanné');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      final File? verso = await _scannerService.scanDocument();
      if (verso == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _currentStep = 'Verso annulé. Veuillez recommencer.';
        });
        _showErrorDialog('Scan du verso annulé. Veuillez recommencer pour numériser les deux faces.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _versoImage = verso;
        _isCapturing = false;
        _currentStep = 'Deux faces scannées. Prêt pour l\'extraction.';
      });
      _showSuccessMessage('Verso scanné');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isProcessing = false;
        _currentStep = 'Erreur pendant le scan';
      });
      _showErrorDialog('Erreur lors du scan : $e');
    }
  }

  Future<void> _captureSequentialImages() async {
    if (_isCapturing || _isProcessing) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = false;
      _rectoImage = null;
      _versoImage = null;
      _currentStep = 'Capture du recto...';
    });

    try {
      final XFile? rectoPhoto = await _takePhoto();

      if (rectoPhoto == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _currentStep = 'Capture annulée';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _rectoImage = File(rectoPhoto.path);
        _currentStep = 'Recto enregistré. Préparez le verso...';
      });

      _showSuccessMessage('Recto enregistré');

      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      setState(() {
        _currentStep = 'Capture du verso...';
      });

      final XFile? versoPhoto = await _takePhoto();

      if (versoPhoto == null) {
        if (!mounted) return;

        setState(() {
          _isCapturing = false;
          _currentStep = 'Verso annulé. Veuillez recommencer.';
        });

        _showErrorDialog(
          'Capture du verso annulée. Veuillez recommencer pour capturer les deux faces.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _versoImage = File(versoPhoto.path);
        _isCapturing = false;
        _currentStep = 'Deux faces capturées. Prêt pour l\'extraction.';
      });

      _showSuccessMessage('Verso enregistré');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _isProcessing = false;
        _currentStep = 'Erreur pendant la capture';
      });

      _showErrorDialog('Erreur lors de la capture : $e');
    }
  }

  Future<void> _extractInformation() async {
    if (_rectoImage == null || _versoImage == null) {
      _showErrorDialog('Veuillez capturer le recto et le verso de la CNI.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 'Analyse OCR en cours...';
    });

    try {
      final Map<String, String> ocrResults = await _ocrService.scanBothSides(
        _rectoImage!,
        _versoImage!,
      );

      final String rectoText = ocrResults['recto'] ?? '';
      final String versoText = ocrResults['verso'] ?? '';

      final Map<String, String?> rectoData = CniParser.parseRecto(rectoText);
      final Map<String, String?> versoData = CniParser.parseVerso(versoText);

      final PatientData patientData = CniParser.combineData(
        rectoData,
        versoData,
      ).copyWith(sourceType: DocumentType.cni);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _currentStep = 'Extraction terminée';
      });

      final bool hasAnyData =
          patientData.nom.trim().isNotEmpty ||
              patientData.prenom.trim().isNotEmpty ||
              patientData.dateNaissance.trim().isNotEmpty ||
              patientData.numeroDocument.trim().isNotEmpty ||
              patientData.groupeSanguin.trim().isNotEmpty;

      if (!hasAnyData) {
        _showErrorDialog(
          "Aucune information n'a pu être extraite. Veuillez reprendre les photos avec une meilleure lumière.",
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientFormScreen(
            initialData: patientData,
            imagePath: _rectoImage!.path,
            ocrRawText: '$rectoText\n$versoText',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _currentStep = "Erreur pendant l'extraction";
      });

      _showErrorDialog("Erreur lors de l'extraction : $e");
    }
  }

  void _resetCapture() {
    setState(() {
      _rectoImage = null;
      _versoImage = null;
      _isCapturing = false;
      _isProcessing = false;
      _currentStep = 'Prêt pour la capture';
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Erreur'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bool hasNoImages = _rectoImage == null && _versoImage == null;
    final bool hasBothImages = _rectoImage != null && _versoImage != null;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Scanner CNI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),

              // CHANGEMENT : Expanded contient maintenant un SingleChildScrollView
              // pour que le contenu puisse défiler quand l'écran est trop petit.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: hasNoImages
                      ? _buildInitialState()
                      : _buildCapturedImages(),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _buildBottomActions(hasNoImages, hasBothImages),
              ),
            ],
          ),

          if (_rectoImage != null && _versoImage == null)
            Positioned(
              left: 24,
              bottom: 105,
              child: _buildRectoMiniature(),
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
              Icons.credit_card,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Préremplissage par CNI',
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

  Widget _buildInitialState() {
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
              Icons.document_scanner_outlined,
              color: _primaryColor,
              size: 52,
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Scan automatique recto / verso',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "Le scanner détecte automatiquement les bords de la carte et corrige la perspective. Il s'ouvre deux fois : d'abord pour le recto, puis pour le verso.",
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
            title: 'Scanner le recto',
            subtitle: 'Pointez la caméra vers la face avant — les bords sont détectés automatiquement.',
            icon: Icons.crop_portrait,
          ),

          const SizedBox(height: 14),

          _buildStep(
            number: '2',
            title: 'Scanner le verso',
            subtitle: 'Le scanner se rouvre directement pour la deuxième face.',
            icon: Icons.flip,
          ),

          const SizedBox(height: 14),

          _buildStep(
            number: '3',
            title: 'Lancer l\'extraction',
            subtitle: "Appuyez sur \"Extraire\" pour démarrer l'analyse OCR.",
            icon: Icons.auto_awesome,
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
        border: Border.all(
          color: Colors.grey.shade200,
        ),
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

          Icon(
            icon,
            color: _primaryColor,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedImages() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: _buildImageCard(
            title: 'Recto',
            image: _rectoImage,
            icon: Icons.credit_card,
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 200,
          child: _buildImageCard(
            title: 'Verso',
            image: _versoImage,
            icon: Icons.flip_to_back,
          ),
        ),

        const SizedBox(height: 16),

        if (_isProcessing)
          _buildStatusBanner(
            color: Colors.blue,
            icon: Icons.hourglass_top,
            text: 'Extraction OCR en cours...',
          )
        else if (_rectoImage != null && _versoImage != null)
          _buildStatusBanner(
            color: Colors.green,
            icon: Icons.check_circle,
            text: 'Les deux faces ont été capturées',
          )
        else if (_rectoImage != null)
            _buildStatusBanner(
              color: Colors.orange,
              icon: Icons.flip_camera_android,
              text: 'Recto enregistré. Capture du verso en attente...',
            ),
      ],
    );
  }

  Widget _buildImageCard({
    required String title,
    required File? image,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: image == null
                ? Center(
              child: Icon(
                icon,
                size: 58,
                color: Colors.grey[300],
              ),
            )
                : Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRectoMiniature() {
    return Container(
      width: 82,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              _rectoImage!,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool hasNoImages, bool hasBothImages) {
    if (hasNoImages) {
      final bool busy = _isCapturing || _isProcessing;
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: busy ? null : _scanSequential,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner),
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
              onPressed: busy ? null : _pickGallerySequential,
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

    if (_isCapturing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text(
            'Capture du verso...',
            style: TextStyle(fontSize: 17),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (_isProcessing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text(
            'Extraction en cours...',
            style: TextStyle(fontSize: 17),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetCapture,
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
            onPressed: hasBothImages ? _extractInformation : null,
            icon: const Icon(Icons.check_circle),
            label: const Text(
              'Extraire',
              style: TextStyle(fontWeight: FontWeight.bold),
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