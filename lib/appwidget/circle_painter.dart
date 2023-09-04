import "dart:ui" as ui;
import "package:flutter/material.dart";

class CirclePainter extends CustomPainter {
  final bool isSelected;
  final ImageProvider? imageProvider;
  CirclePainter({required this.isSelected, this.imageProvider});

  @override
  void paint(Canvas canvas, Size size) async {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

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

    if (imageProvider != null) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);
      final radius = size.width / 2;

      final center = Offset(size.width / 2, size.height / 2);

      final paint = Paint()
        ..color = Colors.transparent // Set the background color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));

      // Clip the canvas to a circular path
      recorderCanvas.clipPath(path);

      // Load and paint the image
      final stream = imageProvider!.resolve(ImageConfiguration(size: size));
      stream.addListener(
        ImageStreamListener((img, synchronousCall) async {
          final imgSize =
              Size(img.image.width.toDouble(), img.image.height.toDouble());
          final scale = radius * 2 / imgSize.shortestSide;
          final fittedSize = imgSize * scale;

          final left = center.dx - fittedSize.width / 2;
          final top = center.dy - fittedSize.height / 2;

          final srcRect = Rect.fromPoints(Offset.zero, Offset(radius, radius));
          final dstRect = Rect.fromPoints(
            Offset(left, top),
            Offset(left + fittedSize.width, top + fittedSize.height),
          );

          recorderCanvas.drawImageRect(img.image, srcRect, dstRect, paint);

          final picture = recorder.endRecording();
          final imgForCanvas =
              await picture.toImage(size.width.toInt(), size.height.toInt());
          final imgBytes =
              await imgForCanvas.toByteData(format: ui.ImageByteFormat.png);

          final buffer = imgBytes!.buffer.asUint8List();

          final decodedImage = await decodeImageFromList(buffer);

          final imagePaint = Paint();
          canvas.drawImageRect(
            decodedImage,
            Rect.fromPoints(
              Offset(0, 0),
              Offset(
                decodedImage.width.toDouble(),
                decodedImage.height.toDouble(),
              ),
            ),
            Rect.fromPoints(Offset(0, 0), Offset(size.width, size.height)),
            imagePaint,
          );
        }),
      );
    }

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
