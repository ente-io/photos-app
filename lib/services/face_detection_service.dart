import 'dart:io';

import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:logging/logging.dart';

class FaceDetectionService {
  final _logger = Logger("FaceDetectionService");
  
  FaceDetectionService._privateConstructor();

  static FaceDetectionService instance =
      FaceDetectionService._privateConstructor();

  Future<List<File>> getFaceCrops(File file) async {
    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);
    final faces = await faceDetector.processImage(InputImage.fromFile(file));
    final List<File> faceCrops = [];
    for (final face in faces) {
      try {
        final croppedFace = await FlutterNativeImage.cropImage(
          file.path,
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt(),
        );
        faceCrops.add(croppedFace);
      } catch (e) {
        _logger.severe(e);
      }
    }
    return faceCrops;
  }
}
