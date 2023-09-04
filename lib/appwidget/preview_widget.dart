import "dart:io";

import "package:flutter/material.dart";
import "package:photos/appwidget/heart_painter.dart";

Widget selectedShapeWidget(int id, double side, File file) {
  switch (id) {
    case 1:
      return Container(
        height: side,
        width: side,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 3,
            color: Colors.green,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          image: DecorationImage(
            fit: BoxFit.fill,
            image: FileImage(file),
          ),
        ),
      );
    case 2:
      return CustomPaint(
        painter: HeartPainter(isSelected: true),
        child: ClipPath(
          clipper: HeartClipper(),
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: Colors.black,
              image: DecorationImage(image: FileImage(file), fit: BoxFit.fill),
            ),
            // child: Image.file(file),
          ),
        ),
      );
    default:
      return Container(
        height: side,
        width: side,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          border: Border.all(
            width: 3,
            color: Colors.green,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          image: DecorationImage(
            fit: BoxFit.fill,
            image: FileImage(file),
          ),
        ),
      );
  }
}

class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
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
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
