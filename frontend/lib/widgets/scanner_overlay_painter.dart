import 'package:flutter/material.dart';

/// Painter personalizado para dibujar líneas de mira estilo escáner industrial
/// sobre el visor de la cámara.
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Dibujar un marco en el centro de la pantalla
    final double width = size.width * 0.7;
    final double height = size.height * 0.5;
    final double left = (size.width - width) / 2;
    final double top = (size.height - height) / 2;
    final rect = Rect.fromLTWH(left, top, width, height);

    canvas.drawRect(rect, paint);

    // Dibujar esquinas reforzadas con color verde menta sólido
    final cornerPaint = Paint()
      ..color = const Color(0xFF34D399)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const double lineLength = 20;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(left, top),
      Offset(left + lineLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + lineLength),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(left + width, top),
      Offset(left + width - lineLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + width, top),
      Offset(left + width, top + lineLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + lineLength, top + height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left, top + height - lineLength),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(left + width, top + height),
      Offset(left + width - lineLength, top + height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + width, top + height),
      Offset(left + width, top + height - lineLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
