import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data' show Uint8List;

// import 'dart:ui' as ui;
// import "package:flutter/material.dart";
import "package:flutter/material.dart";
import 'package:image/image.dart' as image_lib;
import "package:logging/logging.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:synchronized/synchronized.dart";

class CouldNotConvertToImageImage implements Exception {}

// TODO: the image conversion below is what makes the whole pipeline slow, so come up with different solution

/// Converts a [Uint8List] to an [image_lib.Image] object.
image_lib.Image? _convertUint8ListToImagePackageImage(Uint8List imageData) {
  return image_lib.decodeImage(imageData);
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
  FaceDetectionRelative faceDetection,
) async {
  final image = await ImageConversionIsolate.instance.convert(imageData);
  if (image == null) return null;
  debugPrint("image: ${image.width}x ${image.height}");
  debugPrint(
      "faceDetection ${faceDetection.xMinBox}x ${faceDetection.yMinBox}x ${faceDetection.width}x ${faceDetection.height}");
  debugPrint("x: ${(faceDetection.xMinBox * image.width).round() - 5}");
  debugPrint("y: ${(faceDetection.yMinBox * image.height).round() - 5}");
  debugPrint("width: ${(faceDetection.width * image.width).round() + 10}");
  debugPrint("height: ${(faceDetection.height * image.height).round() + 10}");

  // final faceThumbnail = image_lib.copyCrop(
  //   image,
  //   x: (faceDetection.xMinBox * image.width).round() - 5,
  //   y: (faceDetection.yMinBox * image.height).round() - 5,
  //   width: (faceDetection.width * image.width).round() + 10,
  //   height: (faceDetection.height * image.height).round() + 10,
  // );

  return _convertImagePackageImageToUint8List(image);
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
  /// Then you can use `convert()` to get the image, so `ImageConversionIsolate.instance.convert(imageData)`
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
      final sendPort = message[1] as SendPort;

      final result = _convertUint8ListToImagePackageImage(data);
      // if (result != null) {
      sendPort.send(result);
      // } else {
      //   sendPort.send(CouldNotConvertToImageImage());
      // }
    });
  }

  /// Converts a [Uint8List] to an [image_lib.Image] object inside a separate isolate.
  Future<image_lib.Image?> convert(Uint8List data) async {
    await ensureSpawned();
    final completer = Completer<image_lib.Image?>();
    final answerPort = ReceivePort();

    _mainSendPort.send([data, answerPort.sendPort]);

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
