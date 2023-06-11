import "dart:ui" as ui;
import "package:flutter/material.dart";

class CirclePainter extends CustomPainter {
  final bool isSelected;
  CirclePainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint1 = Paint()
      ..shader = ui.Gradient.radial(center, radius / 1.5, [
        Colors.greenAccent,
        Colors.green,
      ])
      ..style = PaintingStyle.fill;

    if (isSelected) {
      canvas.drawCircle(center, radius, paint1);
    }

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
