import "dart:ui" as ui;
import "package:flutter/material.dart";

class SquarePainter extends CustomPainter {
  final bool isSelected;

  SquarePainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(0, 1, size.width, size.height - 1);

    final fillPaint = Paint()
      ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2), size.height / 1.5, [
        Colors.greenAccent,
        Colors.green,
      ])
      ..style = PaintingStyle.fill;

    if (isSelected) {
      canvas.drawRect(rect, fillPaint);
    }

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
