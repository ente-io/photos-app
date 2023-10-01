import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data' show Uint8List;

// import 'dart:ui' as ui;
// import "package:flutter/material.dart";
// import "package:flutter/material.dart";
import 'package:image/image.dart' as image_lib;
import "package:logging/logging.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:synchronized/synchronized.dart";

class CouldNotConvertToImageImage implements Exception {}

// TODO: the image conversion below is what makes the whole pipeline slow, so come up with different solution

/// Converts a [Uint8List] to an [image_lib.Image] object.
image_lib.Image? _convertUint8ListToImagePackageImage(
  Uint8List imageData, {
  String? path,
}) {
  image_lib.Image? image;
  if (path != null) {
    image = image_lib.decodeNamedImage(path, imageData);
  } else {
    image = image_lib.decodeImage(imageData);
  }
  return image;
}

// // TODO: try out the image_pixel package
// /// Converts a [Uint8List] to an [image_lib.Image] object.
// image_lib.Image? getImagePixel(Uint8List imageData) {
//   return image_lib.decodeImage(imageData);
// }

// /// Converts a [Uint8List] to an [image_lib.Image] object.
// image_lib.Image? _convertUint8ListToImagePackageImage(Uint8List imageData) async {
//   final Image test = Image.memory(imageData);
//   // test.

//   ui.Codec codec = await ui.instantiateImageCodec(imageData);
//   return image_lib.decodeImage(imageData);
// }

Uint8List _convertImagePackageImageToUint8List(image_lib.Image image) {
  return image_lib.encodeJpg(image);
}

/// Generates a face thumbnail from [imageData] and a [faceDetection].
Future<Uint8List?> generateFaceThumbnail(
  Uint8List imageData,
  String? imagePath,
  FaceDetectionRelative faceDetection,
) async {
  final image = await ImageConversionIsolate.instance.convert(imageData, imagePath: imagePath);
  if (image == null) return null;

  final faceThumbnail = image_lib.copyCrop(
    image,
    x: (faceDetection.xMinBox * image.width).round() - 20,
    y: (faceDetection.yMinBox * image.height).round() - 30,
    width: (faceDetection.width * image.width).round() + 40,
    height: (faceDetection.height * image.height).round() + 60,
  );

  return _convertImagePackageImageToUint8List(faceThumbnail);
}

/// This class is responsible for converting [Uint8List] to [image_lib.Image].
///
/// Used primarily for ML applications.
class ImageConversionIsolate {
  static const String debugName = "ImageConversionIsolate";

  final _logger = Logger("ImageConversionIsolate");

  final _initLock = Lock();

  late Isolate _isolate;
  late ReceivePort _receivePort = ReceivePort();
  late SendPort _mainSendPort;

  bool isSpawned = false;

  // singleton pattern
  ImageConversionIsolate._privateConstructor();

  /// Use this instance to access the ImageConversionIsolate service. Make sure to call `init()` before using it.
  /// e.g. `await ImageConversionIsolate.instance.init();`
  /// And kill the isolate when you're done with it with `dispose()`, e.g. `ImageConversionIsolate.instance.dispose();`
  ///
  /// Then you can use `convert()` to get the image, so `ImageConversionIsolate.instance.convert(imageData, imagePath: imagePath)`
  static final ImageConversionIsolate instance =
      ImageConversionIsolate._privateConstructor();
  factory ImageConversionIsolate() => instance;

  Future<void> init() async {
    return _initLock.synchronized(() async {
      if (isSpawned) return;

      _receivePort = ReceivePort();

      try {
        _isolate = await Isolate.spawn(
          _isolateMain,
          _receivePort.sendPort,
          debugName: debugName,
        );
        _mainSendPort = await _receivePort.first as SendPort;
        isSpawned = true;
      } catch (e) {
        _logger.severe("Could not spawn isolate", e);
        isSpawned = false;
      }
    });
  }

  Future<void> ensureSpawned() async {
    if (!isSpawned) {
      await init();
    }
  }

  static void _isolateMain(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      final data = message[0] as Uint8List;
      final path = message[1] as String?;
      final sendPort = message[2] as SendPort;

      final result = _convertUint8ListToImagePackageImage(data, path: path);
      // if (result != null) {
      sendPort.send(result);
      // } else {
      //   sendPort.send(CouldNotConvertToImageImage());
      // }
    });
  }

  /// Converts a [Uint8List] to an [image_lib.Image] object inside a separate isolate.
  Future<image_lib.Image?> convert(Uint8List data, {String? imagePath}) async {
    await ensureSpawned();
    final completer = Completer<image_lib.Image?>();
    final answerPort = ReceivePort();

    _mainSendPort.send([data, imagePath, answerPort.sendPort]);

    answerPort.listen((message) {
      // if (message is image_lib.Image?) {
      completer.complete(message);
      // } else if (message is CouldNotConvertToImageImage) {
      //   completer.completeError(message);
      // }
    });

    return completer.future;
  }

  void dispose() {
    if (!isSpawned) return;

    _isolate.kill();
    _receivePort.close();
    isSpawned = false;
  }
}
