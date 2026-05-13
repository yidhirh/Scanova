import 'package:flutter/material.dart';
import 'ocr_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goToOcrScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6FD),
      appBar: AppBar(
        title: const Text('Scanova'),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFDF6FD),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 72,
                color: Color(0xFF2563EB),
              ),

              const SizedBox(height: 24),

              const Text(
                'Bienvenue sur Scanova',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Commencez une première démonstration OCR en scannant un document médical.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _goToOcrScreen(context),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text(
                    'Scanner un document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}