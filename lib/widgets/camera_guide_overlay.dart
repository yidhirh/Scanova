import 'package:flutter/material.dart';

class CameraGuideOverlay extends StatelessWidget {
  const CameraGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GuideFramePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GuideFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final frameWidth = size.width * 0.88;
    final frameHeight = frameWidth * 0.63;
    final left = (size.width - frameWidth) / 2;
    final top = size.height * 0.25;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, frameWidth, frameHeight),
      const Radius.circular(18),
    );

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(rect);
    final overlayPath = Path.combine(PathOperation.difference, fullPath, cutoutPath);

    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rect, borderPaint);

    final cornerPaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 35.0;

    // Coin haut gauche
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // Coin haut droit
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top),
      Offset(left + frameWidth, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top),
      Offset(left + frameWidth, top + cornerLength),
      cornerPaint,
    );

    // Coin bas gauche
    canvas.drawLine(
      Offset(left, top + frameHeight - cornerLength),
      Offset(left, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + frameHeight),
      Offset(left + cornerLength, top + frameHeight),
      cornerPaint,
    );

    // Coin bas droit
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top + frameHeight - cornerLength),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
