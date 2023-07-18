import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as image_lib;

image_lib.Image convertUint8ListToImagePackageImage(Uint8List imageData) {
  return image_lib.decodeImage(imageData)!;
}

Uint8List convertImagePackageImageToUint8List(image_lib.Image image) {
  return image_lib.encodeJpg(image) as Uint8List;
}

extension ColorExtension on int {
  int get r => (this >> 0) & 0xFF;
  int get g => (this >> 8) & 0xFF;
  int get b => (this >> 16) & 0xFF;
  int get alpha => (this >> 24) & 0xFF;
}
