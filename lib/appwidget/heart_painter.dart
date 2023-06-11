import "dart:ui" as ui;
import "package:flutter/material.dart";

class HeartPainter extends CustomPainter {
  final bool isSelected;

  HeartPainter({required this.isSelected});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    final paint1 = Paint();
    paint1
      ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2), size.height / 2, [
        Colors.greenAccent,
        Colors.green,
      ])
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
    final width = size.width;
    final height = size.height;

    final path = Path();
    path.moveTo(0.5 * width, height * 0.15);
    path.cubicTo(
      0,
      height * -0.25,
      -0.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.moveTo(0.5 * width, height * 0.15);
    path.cubicTo(
      width,
      height * -0.25,
      1.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    if (isSelected) {
      canvas.drawPath(path, paint1);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
