import 'dart:io';

import 'package:flutter/material.dart';

/// Visionneuse plein écran d'images scannées, partagée par les viewers de
/// documents (génériques et bilans). Affiche les pages dans un [PageView]
/// (swipe), chaque page étant zoomable via [InteractiveViewer], avec un
/// compteur de page et des points indicateurs.
///
/// Ouverte au tap sur l'aperçu d'un document : on lui passe la liste des
/// chemins d'images et l'index de la page courante pour préserver le lien
/// page courante → image courante.
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String title;

  const FullscreenImageViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    required this.title,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.imagePaths.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (pageCount > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_currentPage + 1} / $pageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: pageCount == 0
          ? _buildError()
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final file = File(widget.imagePaths[index]);
                    if (!file.existsSync()) return _buildError();
                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _buildError(),
                        ),
                      ),
                    );
                  },
                ),
                if (pageCount > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _buildDots(pageCount),
                  ),
              ],
            ),
    );
  }

  Widget _buildDots(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            'Fichier introuvable',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }
}
